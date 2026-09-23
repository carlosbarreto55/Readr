import Foundation

/// Translates `DownloadEntity` to `DownloadEntry`.
///
/// Free functions, for the same reason as `SeriesMapper`.
enum DownloadMapper {

    /// - Parameters:
    ///   - entity: The stored row.
    ///   - progress: The in-memory progress of the active download. The store does
    ///     not persist it, because it is stale the moment the app stops.
    /// - Returns: `nil` if the stored row's URLs or content type cannot be read.
    static func toDomain(_ entity: DownloadEntity, progress: DownloadProgress?) -> DownloadEntry? {
        guard let seriesURL = URL(string: entity.seriesURL),
            let chapterURL = URL(string: entity.chapterURL),
            let contentType = ContentType(rawValue: entity.contentTypeRaw)
        else {
            return nil
        }
        return DownloadEntry(
            chapter: Chapter(
                sourceID: entity.sourceID,
                seriesURL: seriesURL,
                url: chapterURL,
                name: entity.chapterName,
                number: entity.chapterNumber
            ),
            seriesTitle: entity.seriesTitle,
            contentType: contentType,
            state: state(of: entity, progress: progress),
            enqueuedAt: entity.enqueuedAt,
            byteCount: entity.byteCount
        )
    }

    private static func state(
        of entity: DownloadEntity, progress: DownloadProgress?
    ) -> DownloadState {
        switch DownloadStateRaw(rawValue: entity.stateRaw) {
        case .downloading:
            return .downloading(progress ?? .indeterminate)
        case .completed:
            return .completed
        case .failed:
            return .failed(
                message: entity.errorMessage ?? "The download failed.",
                isRetryable: entity.isRetryable)
        // An unreadable state is treated as pending: the entry is retried rather
        // than lost.
        case .pending, nil:
            return .pending
        }
    }
}
