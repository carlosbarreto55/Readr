import Foundation
import Testing

@testable import Readr

/// `.serialized` because `StubURLProtocol` is reachable only through a static —
/// `URLProtocol` is instantiated by the loading system, so there is nowhere to
/// inject a per-test registry.
@Suite("HTTPClient", .serialized)
struct HTTPClientTests {
    private let url = URL(string: "https://example.test/page")!

    @Test("A successful response comes back as text")
    func fetchesText() async throws {
        let registry = StubURLProtocol.install()
        registry.stub(url, html: "<html><body>hello</body></html>")

        let client = HTTPClient(session: StubURLProtocol.makeSession())
        let text = try await client.text(from: url, source: "Test")

        #expect(text.contains("hello"))
        #expect(registry.cachePolicies == [.reloadIgnoringLocalAndRemoteCacheData])
    }

    @Test("A non-success status throws rather than returning a body to parse")
    func httpErrorThrows() async {
        let registry = StubURLProtocol.install()
        registry.stub(url, html: "<html>Not Found</html>", statusCode: 404)

        let client = HTTPClient(session: StubURLProtocol.makeSession())
        await #expect(throws: SourceError.httpStatus(code: 404, source: "Test", url: url)) {
            try await client.text(from: url, source: "Test")
        }
    }

    /// A 404 body parses perfectly well — into nothing. Without this the caller
    /// sees an empty catalog page and reports a broken parser.
    @Test("A 404 is not retryable; a 503 is")
    func retryabilityFollowsTheStatus() {
        #expect(SourceError.httpStatus(code: 404, source: "T", url: url).isRetryable == false)
        #expect(SourceError.httpStatus(code: 503, source: "T", url: url).isRetryable)
        #expect(SourceError.httpStatus(code: 429, source: "T", url: url).isRetryable)
        #expect(SourceError.timedOut(source: "T", url: url).isRetryable)
        #expect(
            SourceError.requiredFieldMissing(field: "title", source: "T", url: url).isRetryable
                == false)
    }

    @Test("A timeout surfaces as a retryable error, not a hang")
    func timeoutIsRetryable() async {
        let registry = StubURLProtocol.install()
        registry.stub(url, with: .init(error: URLError(.timedOut)))

        let client = HTTPClient(session: StubURLProtocol.makeSession(), timeout: 1)
        do {
            _ = try await client.text(from: url, source: "Test")
            Issue.record("Expected the request to fail")
        } catch let error as SourceError {
            #expect(error == .timedOut(source: "Test", url: url))
            #expect(error.isRetryable)
        } catch {
            Issue.record("Expected a SourceError, got \(error)")
        }
    }

    @Test("A transport failure is retryable and names the source")
    func transportFailureIsRetryable() async {
        let registry = StubURLProtocol.install()
        registry.stub(url, with: .init(error: URLError(.notConnectedToInternet)))

        let client = HTTPClient(session: StubURLProtocol.makeSession())
        do {
            _ = try await client.text(from: url, source: "Test")
            Issue.record("Expected the request to fail")
        } catch let error as SourceError {
            guard case .transport(let source, let failedURL, _) = error else {
                Issue.record("Expected .transport, got \(error)")
                return
            }
            #expect(source == "Test")
            #expect(failedURL == url)
            #expect(error.isRetryable)
        } catch {
            Issue.record("Expected a SourceError, got \(error)")
        }
    }

    /// The bound is what keeps the app from looking like a scraper to a site it
    /// reads from. A limiter that is merely *usually* right is indistinguishable
    /// from a correct one until requests start being refused, so the assertion is
    /// on the peak rather than on the outcome.
    @Test("Concurrency against one host never exceeds the bound")
    func concurrencyIsBounded() async throws {
        let registry = StubURLProtocol.install()
        let urls = (0..<20).map { URL(string: "https://example.test/page/\($0)")! }
        for url in urls {
            registry.stub(url, with: .init(body: Data("ok".utf8), delay: .milliseconds(20)))
        }

        let client = HTTPClient(
            session: StubURLProtocol.makeSession(), maxConcurrentRequestsPerHost: 3)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask { _ = try await client.text(from: url, source: "Test") }
            }
            try await group.waitForAll()
        }

        #expect(registry.peakConcurrency <= 3)
        #expect(await client.peakConcurrency(for: "example.test") <= 3)
        // All twenty still completed — a bound that deadlocks also never exceeds
        // itself, so the count is half the assertion.
        #expect(registry.requestedURLs.count == 20)
    }

    @Test("Each host is bounded independently")
    func hostsAreBoundedIndependently() async throws {
        let registry = StubURLProtocol.install()
        let first = (0..<6).map { URL(string: "https://first.test/p/\($0)")! }
        let second = (0..<6).map { URL(string: "https://second.test/p/\($0)")! }
        for url in first + second {
            registry.stub(url, with: .init(body: Data("ok".utf8), delay: .milliseconds(20)))
        }

        let client = HTTPClient(
            session: StubURLProtocol.makeSession(), maxConcurrentRequestsPerHost: 2)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for url in first + second {
                group.addTask { _ = try await client.text(from: url, source: "Test") }
            }
            try await group.waitForAll()
        }

        #expect(await client.peakConcurrency(for: "first.test") <= 2)
        #expect(await client.peakConcurrency(for: "second.test") <= 2)
        // Two hosts at two each may legitimately overlap to four in total. If the
        // limit were global, the observed peak could never have exceeded two.
        #expect(registry.peakConcurrency > 2)
    }

    /// A thrown request that leaked its permit would shrink the effective bound
    /// on every failure until the source stopped working entirely — and would do
    /// it silently, since each individual request still succeeds.
    @Test("A failing request releases its permit")
    func failureDoesNotLeakAPermit() async throws {
        let registry = StubURLProtocol.install()
        let failing = URL(string: "https://example.test/fails")!
        let working = URL(string: "https://example.test/works")!
        registry.stub(failing, with: .init(error: URLError(.networkConnectionLost)))
        registry.stub(working, html: "ok")

        let client = HTTPClient(
            session: StubURLProtocol.makeSession(), maxConcurrentRequestsPerHost: 1)

        for _ in 0..<5 {
            _ = try? await client.text(from: failing, source: "Test")
        }

        // With the permit leaked, a limit of 1 would have been exhausted by the
        // first failure and this would never return.
        let text = try await client.text(from: working, source: "Test")
        #expect(text == "ok")
    }
}
