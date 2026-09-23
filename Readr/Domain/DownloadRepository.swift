import Foundation

/// Chapters queued and stored for offline reading.
///
/// Requesting a download only records it; the repository drains its queue one
/// chapter at a time, in enqueue order, and publishes every change.
public protocol DownloadRepository: Sendable {

    /// Queues chapters for download and returns at once.
    ///
    /// A chapter already queued or already stored is skipped; a failed one is
    /// returned to pending.
    ///
    /// - Returns: how many chapters were newly queued or re-queued.
    @discardableResult
    func enqueue(
        _ chapters: [Chapter], seriesTitle: String, contentType: ContentType
    ) async throws -> Int

    /// The queue and storage as they are now, then again after every change.
    func updates() async -> AsyncStream<DownloadQueueSnapshot>

    func snapshot() async throws -> DownloadQueueSnapshot

    /// Returns a failed entry to pending.
    func retry(_ chapter: ChapterID) async throws

    /// Removes a pending, downloading, or failed entry and any partial payload.
    func cancel(_ chapter: ChapterID) async throws

    /// Deletes stored chapters and their payloads.
    func delete(_ chapters: [ChapterID]) async throws

    /// Deletes every entry and payload belonging to a series.
    func deleteAll(in series: SeriesID) async throws

    /// Deletes every entry and payload.
    func deleteAll() async throws

    /// The stored payload for a chapter, or `nil` unless it is completely stored.
    func storedContent(for chapter: ChapterID) async -> ChapterContent?

    /// Returns interrupted downloads to pending and starts draining. Called at
    /// launch, when a download that was running when the app died must resume.
    func resume() async

    /// Drains the queue and returns when it is empty or the task is cancelled.
    /// For the background processing task.
    func drainUntilIdle() async
}
