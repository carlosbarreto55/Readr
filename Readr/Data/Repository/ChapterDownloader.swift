import Foundation

/// Everything one chapter's download needs, copied out of its stored entry so the
/// work can run off the repository's actor.
struct DownloadJob: Sendable {
    let key: String
    let chapter: Chapter
    let contentType: ContentType
}

/// Fetches one chapter and stores it complete — or throws having stored nothing
/// in place.
///
/// Separate from the queue so the queue is about ordering and state, and this is
/// about bytes. It runs off the repository's actor; its file I/O never touches
/// the main actor (invariant 7).
struct ChapterDownloader: Sendable {
    let store: ChapterPayloadStore
    let transport: any DownloadTransport

    /// - Parameters:
    ///   - job: The chapter to fetch.
    ///   - progress: Reports pages stored against total pages. Text, fetched in one
    ///     response of unknown size, reports nothing and stays indeterminate.
    /// - Returns: The stored chapter's size in bytes.
    /// - Throws: Whatever the transport threw, `DownloadError`, or
    ///   `CancellationError`. Anything staged is left for the caller to discard.
    func download(
        _ job: DownloadJob, progress: @Sendable (DownloadProgress) async -> Void
    ) async throws -> Int64 {
        let content = try await transport.content(for: job.chapter)
        guard content.matches(job.contentType) else {
            throw DownloadError.unexpectedContent(expected: job.contentType)
        }
        try Task.checkCancellation()

        let staging = try store.beginWrite(for: job.chapter.id, seriesURL: job.chapter.seriesURL)
        var files: [String] = []
        switch content {
        case .text(let html):
            files.append(try store.writeText(html, into: staging))
        case .pages(let urls):
            guard !urls.isEmpty else { throw DownloadError.noPages }
            await progress(DownloadProgress(completed: 0, total: urls.count))
            for (index, url) in urls.enumerated() {
                try Task.checkCancellation()
                let data = try await transport.pageData(from: url, chapter: job.chapter)
                files.append(
                    try store.writePage(data, index: index, sourceURL: url, into: staging))
                await progress(DownloadProgress(completed: index + 1, total: urls.count))
            }
        }
        try Task.checkCancellation()
        return try store.commit(
            ChapterPayloadStore.Manifest(contentType: job.contentType.rawValue, files: files),
            staging: staging, for: job.chapter.id, seriesURL: job.chapter.seriesURL)
    }
}
