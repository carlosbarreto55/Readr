import Foundation
import SwiftData
import Testing

@testable import Readr

/// `download-enqueue` and `download-progress-reporting`, against a real store.
@Suite("Download queue")
struct DownloadQueueTests {
    private let seriesURL = DownloadFixture.seriesURL

    private func chapter(_ number: Int) -> Chapter { DownloadFixture.chapter(number) }

    private func pageURLs(_ chapter: Int, count: Int) -> [URL] {
        DownloadFixture.pageURLs(chapter, count: count)
    }

    @Test("Enqueueing returns at once with a pending entry, then the chapter downloads")
    func enqueueThenDownload() async throws {
        let fixture = try DownloadFixture()
        await fixture.transport.setContent(.success(.text(html: "<p>Hi</p>")), for: chapter(1).url)
        await fixture.transport.hold(chapter(1).url)

        let queued = try await fixture.repository.enqueue(
            [chapter(1)], seriesTitle: "One", contentType: .novel)

        #expect(queued == 1)
        await fixture.transport.waitUntilRequested(chapter(1).url)
        guard case .downloading(let progress) = try await fixture.states().first else {
            Issue.record("Expected downloading")
            return
        }
        #expect(progress.fraction == nil)  // text has no known size: indeterminate

        await fixture.transport.release(chapter(1).url)
        await fixture.repository.waitUntilIdle()

        #expect(try await fixture.states() == [.completed])
        #expect(
            await fixture.repository.storedContent(for: chapter(1).id) == .text(html: "<p>Hi</p>"))
    }
    @Test("Queued and stored chapters are never duplicated; a failed one is re-queued")
    func noDuplicates() async throws {
        let fixture = try DownloadFixture()
        await fixture.transport.setContent(.success(.text(html: "a")), for: chapter(1).url)
        await fixture.transport.setContent(.failure(.failed), for: chapter(2).url)
        await fixture.transport.hold(chapter(1).url)

        try await fixture.repository.enqueue(
            [chapter(1), chapter(2)], seriesTitle: "One", contentType: .novel)
        await fixture.transport.waitUntilRequested(chapter(1).url)
        // Downloading and pending: both skipped.
        #expect(
            try await fixture.repository.enqueue(
                [chapter(1), chapter(2)], seriesTitle: "One", contentType: .novel) == 0)

        await fixture.transport.release(chapter(1).url)
        await fixture.repository.waitUntilIdle()
        #expect(try await fixture.repository.snapshot().entries.count == 2)

        // Stored: skipped. Failed: re-queued.
        await fixture.transport.setContent(.success(.text(html: "b")), for: chapter(2).url)
        #expect(
            try await fixture.repository.enqueue(
                [chapter(1), chapter(2)], seriesTitle: "One", contentType: .novel) == 1)
        await fixture.repository.waitUntilIdle()
        #expect(try await fixture.states() == [.completed, .completed])
    }
    @Test("The queue drains one at a time, in enqueue order, past a failure")
    func sequentialInOrder() async throws {
        let fixture = try DownloadFixture()
        for number in 1...3 {
            await fixture.transport.setContent(
                number == 2 ? .failure(.failed) : .success(.text(html: "\(number)")),
                for: chapter(number).url)
        }

        try await fixture.repository.enqueue(
            [chapter(3), chapter(1), chapter(2)], seriesTitle: "One", contentType: .novel)
        await fixture.repository.waitUntilIdle()

        #expect(
            await fixture.transport.requested
                == [chapter(3).url, chapter(1).url, chapter(2).url])
        #expect(await fixture.transport.peakInFlight == 1)
        let entries = try await fixture.repository.snapshot().entries
        #expect(entries.map(\.chapter.name) == ["Chapter 3", "Chapter 1", "Chapter 2"])
        #expect(entries[0].state == .completed)
        #expect(entries[1].state == .completed)
        guard case .failed(_, let isRetryable) = entries[2].state else {
            Issue.record("Expected the failed entry to stay listed as failed")
            return
        }
        #expect(isRetryable)
    }
    @Test("A failed entry retries back to pending and completes")
    func retry() async throws {
        let fixture = try DownloadFixture()
        await fixture.transport.setContent(.failure(.failed), for: chapter(1).url)
        try await fixture.repository.enqueue([chapter(1)], seriesTitle: "One", contentType: .novel)
        await fixture.repository.waitUntilIdle()

        await fixture.transport.setContent(.success(.text(html: "ok")), for: chapter(1).url)
        try await fixture.repository.retry(chapter(1).id)
        await fixture.repository.waitUntilIdle()

        #expect(try await fixture.states() == [.completed])
    }
    @Test("Page chapters report pages completed against total, and store every page")
    func pageProgress() async throws {
        let fixture = try DownloadFixture()
        let urls = pageURLs(1, count: 3)
        await fixture.transport.setContent(.success(.pages(imageURLs: urls)), for: chapter(1).url)
        await fixture.transport.hold(urls[1])

        try await fixture.repository.enqueue(
            [chapter(1)], seriesTitle: "One", contentType: .manhwa)
        await fixture.transport.waitUntilRequested(urls[1])
        try await waitUntil {
            if case .downloading(let progress) = try? await fixture.states().first {
                return progress == DownloadProgress(completed: 1, total: 3)
            }
            return false
        }

        await fixture.transport.release(urls[1])
        await fixture.repository.waitUntilIdle()

        guard case .pages(let stored) = await fixture.repository.storedContent(for: chapter(1).id)
        else {
            Issue.record("Expected stored pages")
            return
        }
        #expect(stored.count == 3)
        #expect(stored.allSatisfy { $0.isFileURL })
    }
    @Test("Updates arrive as the queue changes, starting with the current state")
    func updatesArePushed() async throws {
        let fixture = try DownloadFixture()
        await fixture.transport.setContent(.success(.text(html: "x")), for: chapter(1).url)
        var updates = await fixture.repository.updates().makeAsyncIterator()

        #expect(await updates.next()?.entries.isEmpty == true)
        try await fixture.repository.enqueue([chapter(1)], seriesTitle: "One", contentType: .novel)

        var sawCompleted = false
        while let snapshot = await updates.next() {
            if snapshot.entries.first?.state == .completed {
                sawCompleted = true
                break
            }
        }
        #expect(sawCompleted)
    }
    @Test("Cancelling the active download removes it and leaves no payload")
    func cancelActive() async throws {
        let fixture = try DownloadFixture()
        await fixture.transport.setContent(.success(.text(html: "x")), for: chapter(1).url)
        await fixture.transport.setContent(.success(.text(html: "y")), for: chapter(2).url)
        await fixture.transport.hold(chapter(1).url)
        try await fixture.repository.enqueue(
            [chapter(1), chapter(2)], seriesTitle: "One", contentType: .novel)
        await fixture.transport.waitUntilRequested(chapter(1).url)

        try await fixture.repository.cancel(chapter(1).id)
        await fixture.transport.release(chapter(1).url)
        await fixture.repository.waitUntilIdle()

        let entries = try await fixture.repository.snapshot().entries
        #expect(entries.map(\.id) == [chapter(2).id])
        #expect(await fixture.repository.storedContent(for: chapter(1).id) == nil)
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.store.directory(for: chapter(1).id, seriesURL: seriesURL)
                    .path(percentEncoded: false)))
    }
    @Test("Pending entries survive relaunch, and an interrupted one resumes as pending")
    func survivesRelaunch() async throws {
        let first = try DownloadFixture()
        await first.transport.setContent(.success(.text(html: "x")), for: chapter(1).url)
        await first.transport.hold(chapter(1).url)
        try await first.repository.enqueue(
            [chapter(1), chapter(2)], seriesTitle: "One", contentType: .novel)
        await first.transport.waitUntilRequested(chapter(1).url)

        // What the store holds at the moment the app dies: one downloading, one
        // pending.
        let context = ModelContext(first.container)
        let rows = try context.fetch(FetchDescriptor<DownloadEntity>(sortBy: [.init(\.sequence)]))
        #expect(rows.map(\.stateRaw) == ["downloading", "pending"])

        // Relaunch: a new repository over the same store.
        let second = try DownloadFixture(container: first.container)
        await second.transport.setContent(.success(.text(html: "x")), for: chapter(1).url)
        await second.transport.setContent(.success(.text(html: "y")), for: chapter(2).url)
        await second.repository.resume()
        await second.repository.waitUntilIdle()

        #expect(try await second.states() == [.completed, .completed])
        await first.transport.release(chapter(1).url)
    }
}
