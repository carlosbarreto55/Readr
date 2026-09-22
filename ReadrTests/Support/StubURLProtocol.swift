import Foundation

/// A `URLProtocol` that answers from a registered table instead of the network.
///
/// Every source test drives this. Tests never reach a real site: a test that does
/// fails when the site is down, passes when the site is broken in a way the
/// fixture would have caught, and is a request to somebody else's server on every
/// CI run.
///
/// Handlers are keyed by absolute URL. A request for a URL nothing registered is
/// a test bug — answered with a 599 so it fails loudly rather than looking like a
/// site that returned nothing.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {

    /// What a stubbed URL answers with.
    struct Response: Sendable {
        var statusCode = 200
        var body: Data = Data()
        var headers: [String: String] = ["Content-Type": "text/html; charset=utf-8"]
        /// How long the response takes. Used to exercise concurrency and timeouts.
        var delay: Duration = .zero
        /// Fail with this instead of responding.
        var error: (any Error)?

        static func html(_ string: String, statusCode: Int = 200) -> Response {
            Response(statusCode: statusCode, body: Data(string.utf8))
        }
    }

    /// Registered stubs, plus the record of what was actually requested.
    ///
    /// A `final class` behind a lock rather than a `static var`: Swift 6 forbids
    /// mutable global state, and every test needs its own isolated table anyway.
    final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var responses: [String: Response] = [:]
        private var requested: [URL] = []
        private var requestedCachePolicies: [URLRequest.CachePolicy] = []
        private var inFlight = 0
        private var peak = 0

        func stub(_ url: URL, with response: Response) {
            lock.withLock { responses[url.absoluteString] = response }
        }

        func stub(_ url: URL, html: String, statusCode: Int = 200) {
            stub(url, with: .html(html, statusCode: statusCode))
        }

        func response(for url: URL) -> Response? {
            lock.withLock { responses[url.absoluteString] }
        }

        func record(_ request: URLRequest) {
            lock.withLock {
                if let url = request.url {
                    requested.append(url)
                }
                requestedCachePolicies.append(request.cachePolicy)
            }
        }

        /// Every URL requested, in order. Lets a test assert what was *not*
        /// requested, which is how a cache hit is proved.
        var requestedURLs: [URL] { lock.withLock { requested } }

        var cachePolicies: [URLRequest.CachePolicy] {
            lock.withLock { requestedCachePolicies }
        }

        func requestCount(for url: URL) -> Int {
            lock.withLock { requested.filter { $0 == url }.count }
        }

        func enter() {
            lock.withLock {
                inFlight += 1
                peak = max(peak, inFlight)
            }
        }

        func leave() { lock.withLock { inFlight -= 1 } }

        /// The most requests this protocol ever had open at once. The independent
        /// check on the limiter's own bookkeeping.
        var peakConcurrency: Int { lock.withLock { peak } }
    }

    /// The registry the current test installed.
    ///
    /// `URLProtocol` is instantiated by the loading system, so there is no way to
    /// pass one in — it has to be reachable statically. Tests that use it run
    /// serialized for that reason.
    nonisolated(unsafe) private static var current = Registry()
    private static let currentLock = NSLock()

    static func install() -> Registry {
        let registry = Registry()
        currentLock.withLock { current = registry }
        return registry
    }

    static var registry: Registry {
        currentLock.withLock { current }
    }

    /// A `URLSession` configured to answer only through this protocol.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        // Nothing may be served from a cache: a test asserting that a second
        // request did not happen must be measuring the app's cache, not URLCache's.
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: configuration)
    }

    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let registry = Self.registry
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        registry.record(request)

        guard let stub = registry.response(for: url) else {
            // Unregistered. Loud on purpose — a silent empty body here would look
            // like a parse failure in whatever test hit it.
            respond(url: url, statusCode: 599, headers: [:], body: Data())
            return
        }

        registry.enter()
        // `URLProtocol` and `URLProtocolClient` predate Sendable and neither is
        // annotated. The loading system calls `startLoading` on one thread per
        // request and `stopLoading` only after it, so nothing here is reachable
        // concurrently — which is the assurance `nonisolated(unsafe)` records.
        nonisolated(unsafe) let sink = self.client
        nonisolated(unsafe) let protocolInstance = self
        Task {
            if stub.delay > .zero {
                try? await Task.sleep(for: stub.delay)
            }
            registry.leave()

            if let error = stub.error {
                sink?.urlProtocol(protocolInstance, didFailWithError: error)
                return
            }
            protocolInstance.respond(
                url: url, statusCode: stub.statusCode, headers: stub.headers, body: stub.body)
        }
    }

    override func stopLoading() {}

    private func respond(url: URL, statusCode: Int, headers: [String: String], body: Data) {
        let response = HTTPURLResponse(
            url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}
