import Foundation

/// How far the active download has got.
///
/// `total` is `nil` when the size is not known — a chapter's text arrives in one
/// response of unannounced length — which reads as indeterminate rather than as
/// zero (`download-progress-reporting`).
public struct DownloadProgress: Sendable, Hashable {
    public let completed: Int
    public let total: Int?

    public init(completed: Int, total: Int?) {
        self.completed = completed
        self.total = total
    }

    public static let indeterminate = DownloadProgress(completed: 0, total: nil)

    /// 0 to 1, or `nil` when indeterminate.
    public var fraction: Double? {
        guard let total, total > 0 else { return nil }
        return min(max(Double(completed) / Double(total), 0), 1)
    }
}

/// Where a chapter is in its download's lifecycle.
public enum DownloadState: Sendable, Hashable {
    case pending
    case downloading(DownloadProgress)
    /// Stored, self-contained, readable offline.
    case completed
    case failed(message: String, isRetryable: Bool)

    /// Pending or downloading: counts as queued for de-duplication.
    public var isQueued: Bool {
        switch self {
        case .pending, .downloading: true
        case .completed, .failed: false
        }
    }
}

/// One chapter in the download queue or in storage.
public struct DownloadEntry: Sendable, Identifiable, Hashable {
    public let chapter: Chapter
    /// For grouping and display; downloads outlive nothing but their own record,
    /// so the title is carried rather than looked up.
    public let seriesTitle: String
    public let contentType: ContentType
    public let state: DownloadState
    public let enqueuedAt: Date
    /// Bytes on disk once completed; 0 otherwise.
    public let byteCount: Int64

    public init(
        chapter: Chapter,
        seriesTitle: String,
        contentType: ContentType,
        state: DownloadState,
        enqueuedAt: Date,
        byteCount: Int64 = 0
    ) {
        self.chapter = chapter
        self.seriesTitle = seriesTitle
        self.contentType = contentType
        self.state = state
        self.enqueuedAt = enqueuedAt
        self.byteCount = byteCount
    }

    public var id: ChapterID { chapter.id }
    public var seriesID: SeriesID { SeriesID(sourceID: chapter.sourceID, url: chapter.seriesURL) }
}

/// The whole queue and storage at one moment, as observers receive it.
public struct DownloadQueueSnapshot: Sendable, Hashable {
    /// In enqueue order.
    public let entries: [DownloadEntry]
    /// Bytes stored under the downloads directory.
    public let storageBytes: Int64

    public init(entries: [DownloadEntry], storageBytes: Int64) {
        self.entries = entries
        self.storageBytes = storageBytes
    }

    public static let empty = DownloadQueueSnapshot(entries: [], storageBytes: 0)

    /// Everything not yet stored: pending, downloading, failed.
    public var queue: [DownloadEntry] {
        entries.filter { $0.state != .completed }
    }

    public var completed: [DownloadEntry] {
        entries.filter { $0.state == .completed }
    }

    public func state(of chapter: ChapterID) -> DownloadState? {
        entries.first { $0.id == chapter }?.state
    }

    /// Every chapter's state, for rendering a chapter list.
    public var states: [ChapterID: DownloadState] {
        Dictionary(entries.map { ($0.id, $0.state) }, uniquingKeysWith: { _, last in last })
    }
}
