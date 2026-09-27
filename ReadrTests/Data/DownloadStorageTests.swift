import Foundation
import SwiftData
import Testing

@testable import Readr

/// `download-offline-reader`: what is stored, what is served, what is freed.
@Suite("Download storage")
struct DownloadStorageTests {
    private let seriesURL = DownloadFixture.seriesURL

    private func chapter(_ number: Int) -> Chapter { DownloadFixture.chapter(number) }

    private func pageURLs(_ chapter: Int, count: Int) -> [URL] {
        DownloadFixture.pageURLs(chapter, count: count)
    }

    @Test(
        "Manga chapters and comic issues download every page and reopen offline",
        arguments: [ContentType.manga, .comic])
    func imagePagesRoundTrip(contentType: ContentType) async throws {
        let fixture = try DownloadFixture()
        let urls = pageURLs(1, count: 2)
        await fixture.transport.setContent(.success(.pages(imageURLs: urls)), for: chapter(1).url)
        for (index, url) in urls.enumerated() {
            await fixture.transport.setPage(.success(Data("page \(index)".utf8)), for: url)
        }
        _ = try await fixture.repository.enqueue(
            [chapter(1)], seriesTitle: "Pages", contentType: contentType)
        await fixture.repository.waitUntilIdle()

        guard case .pages(let stored) = await fixture.repository.storedContent(for: chapter(1).id)
        else {
            Issue.record("Expected stored \(contentType.rawValue) pages")
            return
        }
        #expect(stored.count == 2)
        #expect(stored.allSatisfy { $0.isFileURL })
        #expect(try Data(contentsOf: stored[1]) == Data("page 1".utf8))
    }

    @Test("A chapter with a page that fails is not stored, and nothing partial remains")
    func incompleteIsDiscarded() async throws {
        let fixture = try DownloadFixture()
        let urls = pageURLs(1, count: 2)
        await fixture.transport.setContent(.success(.pages(imageURLs: urls)), for: chapter(1).url)
        await fixture.transport.setPage(.failure(.failed), for: urls[1])

        try await fixture.repository.enqueue(
            [chapter(1)], seriesTitle: "One", contentType: .manhwa)
        await fixture.repository.waitUntilIdle()

        guard case .failed = try await fixture.states().first else {
            Issue.record("Expected failure")
            return
        }
        #expect(await fixture.repository.storedContent(for: chapter(1).id) == nil)
        #expect(fixture.store.totalSize() == 0)
    }
    @Test("Deleting frees storage; delete-all reports zero")
    func deletionFreesStorage() async throws {
        let fixture = try DownloadFixture()
        for number in 1...2 {
            await fixture.transport.setContent(
                .success(.text(html: String(repeating: "x", count: 1_000))),
                for: chapter(number).url)
        }
        try await fixture.repository.enqueue(
            [chapter(1), chapter(2)], seriesTitle: "One", contentType: .novel)
        await fixture.repository.waitUntilIdle()
        let full = try await fixture.repository.snapshot().storageBytes
        #expect(full > 0)

        try await fixture.repository.delete([chapter(1).id])
        let half = try await fixture.repository.snapshot()
        #expect(half.storageBytes < full)
        #expect(half.entries.map(\.id) == [chapter(2).id])
        #expect(await fixture.repository.storedContent(for: chapter(1).id) == nil)

        try await fixture.repository.deleteAll()
        let empty = try await fixture.repository.snapshot()
        #expect(empty.entries.isEmpty)
        #expect(empty.storageBytes == 0)
    }
    @Test("Removing a series' downloads leaves other series alone")
    func deleteSeries() async throws {
        let fixture = try DownloadFixture()
        let otherURL = URL(string: "https://example.test/series/two")!
        let other = Chapter(
            sourceID: 42, seriesURL: otherURL, url: otherURL.appending(path: "c1"), name: "Other")
        await fixture.transport.setContent(.success(.text(html: "a")), for: chapter(1).url)
        await fixture.transport.setContent(.success(.text(html: "b")), for: other.url)
        try await fixture.repository.enqueue([chapter(1)], seriesTitle: "One", contentType: .novel)
        try await fixture.repository.enqueue([other], seriesTitle: "Two", contentType: .novel)
        await fixture.repository.waitUntilIdle()

        try await fixture.repository.deleteAll(in: SeriesID(sourceID: 42, url: seriesURL))

        #expect(try await fixture.repository.snapshot().entries.map(\.id) == [other.id])
        #expect(await fixture.repository.storedContent(for: other.id) == .text(html: "b"))
    }
    @Test("A stored chapter whose files vanished stops claiming to be downloaded")
    func vanishedPayload() async throws {
        let fixture = try DownloadFixture()
        await fixture.transport.setContent(.success(.text(html: "x")), for: chapter(1).url)
        try await fixture.repository.enqueue([chapter(1)], seriesTitle: "One", contentType: .novel)
        await fixture.repository.waitUntilIdle()

        fixture.store.deleteAll()

        #expect(await fixture.repository.storedContent(for: chapter(1).id) == nil)
        guard case .failed(_, let isRetryable) = try await fixture.states().first else {
            Issue.record("Expected the entry to be marked failed")
            return
        }
        #expect(isRetryable)
    }
    @Test("Content of the wrong shape fails the download")
    func wrongShapeFails() async throws {
        let fixture = try DownloadFixture()
        await fixture.transport.setContent(.success(.text(html: "x")), for: chapter(1).url)
        try await fixture.repository.enqueue(
            [chapter(1)], seriesTitle: "One", contentType: .manhwa)
        await fixture.repository.waitUntilIdle()

        guard case .failed = try await fixture.states().first else {
            Issue.record("Expected failure")
            return
        }
    }
}
