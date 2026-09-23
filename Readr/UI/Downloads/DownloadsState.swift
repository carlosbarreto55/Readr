import Foundation

/// Stored chapters of one series.
struct DownloadSeriesGroup: Sendable, Identifiable, Equatable {
    let seriesID: SeriesID
    let title: String
    /// In chapter order.
    let entries: [DownloadEntry]
    let byteCount: Int64

    var id: SeriesID { seriesID }
}

struct DownloadsState {
    var isLoaded = false
    /// Pending, downloading, and failed, in enqueue order.
    var queue: [DownloadEntry] = []
    var groups: [DownloadSeriesGroup] = []
    var storageBytes: Int64 = 0
    var isDeleteAllConfirmationPresented = false
    var errorMessage: String?

    var isEmpty: Bool { queue.isEmpty && groups.isEmpty }

    var storageLabel: String {
        ByteCountFormatter.string(fromByteCount: storageBytes, countStyle: .file)
    }

    /// Builds renderable state from a queue snapshot.
    static func grouping(
        _ snapshot: DownloadQueueSnapshot
    ) -> (
        queue: [DownloadEntry], groups: [DownloadSeriesGroup]
    ) {
        let grouped = Dictionary(grouping: snapshot.completed, by: \.seriesID)
        let groups = grouped.map { seriesID, entries in
            let ordered = entries.sorted(by: chapterPrecedes)
            let title = ordered.first.map {
                Series(
                    sourceID: seriesID.sourceID, url: seriesID.url, title: $0.seriesTitle,
                    contentType: $0.contentType
                ).displayTitle
            }
            return DownloadSeriesGroup(
                seriesID: seriesID,
                title: title ?? "",
                entries: ordered,
                byteCount: entries.reduce(0) { $0 + $1.byteCount })
        }
        .sorted { lhs, rhs in
            let order = lhs.title.localizedStandardCompare(rhs.title)
            if order != .orderedSame { return order == .orderedAscending }
            return lhs.seriesID.url.absoluteString < rhs.seriesID.url.absoluteString
        }
        return (snapshot.queue, groups)
    }

    private static func chapterPrecedes(_ lhs: DownloadEntry, _ rhs: DownloadEntry) -> Bool {
        switch (lhs.chapter.number, rhs.chapter.number) {
        case (.some(let left), .some(let right)) where left != right:
            return left < right
        default:
            return lhs.chapter.name.localizedStandardCompare(rhs.chapter.name) == .orderedAscending
        }
    }
}

enum DownloadsAction: Sendable {
    case retry(ChapterID)
    case cancel(ChapterID)
    case delete([ChapterID])
    case deleteSeries(SeriesID)
    case requestDeleteAll
    case cancelDeleteAll
    case confirmDeleteAll
    case openSeries(SeriesID)
    case dismissError
}

enum DownloadsEffect: Sendable, Equatable {
    case openSeries(SeriesID)
}
