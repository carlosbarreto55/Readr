import Foundation

/// Which direction the chapter list is shown in. Reading order is fixed; this is
/// only how the list is presented.
enum SeriesChapterOrder: String, CaseIterable, Sendable, Identifiable {
    case newestFirst
    case oldestFirst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newestFirst: "Newest First"
        case .oldestFirst: "Oldest First"
        }
    }
}

enum SeriesPhase: Sendable, Equatable {
    /// Nothing to show yet.
    case loading
    /// A series is shown; its chapters may still be loading.
    case loaded
    /// Nothing could be shown at all.
    case failed(message: String)
}

struct SeriesState {
    var phase: SeriesPhase = .loading
    var series: Series?
    var sourceName = ""
    /// In reading order, first chapter first.
    var chapters: [LibraryChapter] = []
    var isSaved = false
    var isRefreshing = false
    /// A refresh failed while something was already shown. The content stays.
    var refreshFailure: String?
    var membershipFailure: String?
    var chapterOrder: SeriesChapterOrder = .newestFirst
    var isSynopsisExpanded = false

    /// The chapters in the order the list presents them.
    var displayedChapters: [LibraryChapter] {
        chapterOrder == .oldestFirst ? chapters : chapters.reversed()
    }

    /// Where Continue Reading opens.
    var continueTarget: LibraryChapter? {
        ChapterReadingOrder.continueTarget(in: chapters)
    }

    /// Continue rather than Start once anything has been read.
    var hasReadingHistory: Bool {
        chapters.contains { $0.isRead || $0.isInProgress }
    }

    var unreadCount: Int {
        chapters.count(where: { !$0.isRead })
    }

    /// Status, shape, and source, for the header.
    var metadataLine: String {
        guard let series else { return sourceName }
        var parts: [String] = []
        if series.status != .unknown {
            parts.append(series.status.rawValue.capitalized)
        }
        parts.append(series.contentType == .novel ? "Novel" : "Manhwa")
        if !sourceName.isEmpty {
            parts.append(sourceName)
        }
        return parts.joined(separator: " · ")
    }

    var chapterCountLabel: String {
        switch chapters.count {
        case 0: "Chapters"
        case 1: "1 Chapter"
        default: "\(chapters.count) Chapters"
        }
    }
}

enum SeriesAction: Sendable {
    case appeared
    case retry
    case toggleLibrary
    case retryMembership
    case dismissMembershipFailure
    case dismissRefreshFailure
    case openChapter(ChapterID)
    case continueReading
    case setRead([ChapterID], isRead: Bool)
    /// Marks every chapter before this one, in reading order, as read.
    case markPreviousRead(ChapterID)
    case selectChapterOrder(SeriesChapterOrder)
    case toggleSynopsis
}

enum SeriesEffect: Sendable, Equatable {
    case openReader(ReaderRoute)
}
