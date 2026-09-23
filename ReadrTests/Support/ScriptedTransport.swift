import Foundation

@testable import Readr

/// A `DownloadTransport` answering from a table, able to hold any request in
/// flight until the test releases it — which is how "exactly one downloading at a
/// time" and cancellation mid-download are observed rather than inferred.
actor ScriptedTransport: DownloadTransport {
    private var contents: [URL: Result<ChapterContent, FakeRepositoryError>] = [:]
    private var pages: [URL: Result<Data, FakeRepositoryError>] = [:]
    private var held: Set<URL> = []
    private var gates: [URL: CheckedContinuation<Void, Never>] = [:]
    private var startWaiters: [URL: [CheckedContinuation<Void, Never>]] = [:]
    private var inFlight = 0

    private(set) var requested: [URL] = []
    private(set) var peakInFlight = 0

    func setContent(_ result: Result<ChapterContent, FakeRepositoryError>, for chapter: URL) {
        contents[chapter] = result
    }

    func setPage(_ result: Result<Data, FakeRepositoryError>, for url: URL) {
        pages[url] = result
    }

    /// The next request for `url` waits until `release(_:)`.
    func hold(_ url: URL) {
        held.insert(url)
    }

    func release(_ url: URL) {
        held.remove(url)
        gates.removeValue(forKey: url)?.resume()
    }

    /// Returns once a request for `url` has started.
    func waitUntilRequested(_ url: URL) async {
        guard !requested.contains(url) else { return }
        await withCheckedContinuation { startWaiters[url, default: []].append($0) }
    }

    func content(for chapter: Chapter) async throws -> ChapterContent {
        try await perform(chapter.url) {
            try (contents[chapter.url] ?? .failure(.failed)).get()
        }
    }

    func pageData(from url: URL, chapter: Chapter) async throws -> Data {
        try await perform(url) {
            try (pages[url] ?? .success(Data("page".utf8))).get()
        }
    }

    private func perform<Value>(_ url: URL, answer: () throws -> Value) async throws -> Value {
        requested.append(url)
        inFlight += 1
        peakInFlight = max(peakInFlight, inFlight)
        for waiter in startWaiters.removeValue(forKey: url) ?? [] {
            waiter.resume()
        }
        if held.contains(url) {
            await withCheckedContinuation { gates[url] = $0 }
        }
        inFlight -= 1
        return try answer()
    }
}
