import Foundation

@testable import Readr

/// A `DownloadRepository` that records requests and publishes whatever snapshot
/// a test pushes. The real queue is tested in `DownloadRepositoryTests`.
actor FakeDownloadRepository: DownloadRepository {
    struct Enqueued: Sendable, Equatable {
        let chapters: [ChapterID]
        let seriesTitle: String
        let contentType: ContentType
    }

    private var current: DownloadQueueSnapshot
    private var continuations: [UUID: AsyncStream<DownloadQueueSnapshot>.Continuation] = [:]
    private var stored: [ChapterID: ChapterContent] = [:]
    private(set) var enqueued: [Enqueued] = []
    private(set) var retried: [ChapterID] = []
    private(set) var cancelled: [ChapterID] = []
    private(set) var deleted: [ChapterID] = []
    private(set) var deletedSeries: [SeriesID] = []
    private(set) var deleteAllCalls = 0
    private(set) var storedContentCalls: [ChapterID] = []

    init(snapshot: DownloadQueueSnapshot = .empty) {
        current = snapshot
    }

    /// Replaces the snapshot and pushes it to every observer.
    func publish(_ snapshot: DownloadQueueSnapshot) {
        current = snapshot
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    func store(_ content: ChapterContent, for id: ChapterID) {
        stored[id] = content
    }

    func observerCount() -> Int { continuations.count }

    func enqueue(_ chapters: [Chapter], seriesTitle: String, contentType: ContentType) -> Int {
        enqueued.append(
            Enqueued(
                chapters: chapters.map(\.id), seriesTitle: seriesTitle, contentType: contentType))
        return chapters.count
    }

    func updates() -> AsyncStream<DownloadQueueSnapshot> {
        let (stream, continuation) = AsyncStream.makeStream(of: DownloadQueueSnapshot.self)
        let id = UUID()
        continuations[id] = continuation
        continuation.yield(current)
        continuation.onTermination = { _ in Task { await self.drop(id) } }
        return stream
    }

    func snapshot() -> DownloadQueueSnapshot { current }
    func retry(_ chapter: ChapterID) { retried.append(chapter) }
    func cancel(_ chapter: ChapterID) { cancelled.append(chapter) }
    func delete(_ chapters: [ChapterID]) { deleted.append(contentsOf: chapters) }
    func deleteAll(in series: SeriesID) { deletedSeries.append(series) }

    func deleteAll() {
        deleteAllCalls += 1
        publish(DownloadQueueSnapshot(entries: [], storageBytes: 0))
    }

    func storedContent(for chapter: ChapterID) -> ChapterContent? {
        storedContentCalls.append(chapter)
        return stored[chapter]
    }

    func resume() {}
    func drainUntilIdle() {}

    private func drop(_ id: UUID) {
        continuations[id] = nil
    }
}
