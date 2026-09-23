import Foundation

/// What the Reader renders: parsed text blocks, or page images in reading order.
enum ReaderDocument: Sendable, Equatable {
    case text([ChapterTextBlock])
    case pages([URL])

    /// How many position units the document has: blocks or pages.
    var length: Int {
        switch self {
        case .text(let blocks): blocks.count
        case .pages(let urls): urls.count
        }
    }
}

struct ReaderFailure: Sendable, Equatable {
    let message: String
    let isRetryable: Bool
}

enum ReaderPhase: Sendable, Equatable {
    case loading
    case loaded
    case failed(ReaderFailure)
}

struct ReaderState {
    let route: ReaderRoute
    var phase: ReaderPhase = .loading
    var document: ReaderDocument?
    /// In reading order.
    var chapters: [LibraryChapter] = []
    var currentChapterID: ChapterID
    var seriesTitle = ""
    var controlsVisible = true
    /// 0 to 1 through the current chapter.
    var progress: Double = 0
    /// Where the renderer starts, as a position unit (block or page index).
    var initialIndex = 0
    /// Bumped per load, so a renderer resets its scroll position for a new chapter.
    var documentGeneration = 0
    var preferences: ReaderPreferences
    /// `false` when the series is not in the library, so progress is not kept.
    var isProgressStored = true
    var isChapterListPresented = false
    var isSettingsPresented = false

    init(route: ReaderRoute, preferences: ReaderPreferences) {
        self.route = route
        self.currentChapterID = route.id
        self.preferences = preferences
    }

    var currentIndex: Int? {
        chapters.firstIndex { $0.id == currentChapterID }
    }

    var currentChapter: LibraryChapter? {
        currentIndex.map { chapters[$0] }
    }

    var chapterTitle: String {
        currentChapter?.chapter.name ?? ""
    }

    /// Disabled rather than hidden at the first chapter, per
    /// `unified-reader-screen`.
    var hasPrevious: Bool {
        guard let currentIndex else { return false }
        return currentIndex > 0
    }

    var hasNext: Bool {
        guard let currentIndex else { return false }
        return currentIndex < chapters.count - 1
    }

    var progressLabel: String {
        "\(Int((progress * 100).rounded()))%"
    }
}

enum ReaderAction: Sendable {
    case appeared
    case retry
    case toggleControls
    case previousChapter
    case nextChapter
    case selectChapter(ChapterID)
    case showChapterList(Bool)
    case showSettings(Bool)
    /// The renderer's first visible block or page changed.
    case positionChanged(index: Int)
    /// The renderer showed the end of the chapter.
    case reachedEnd
    case setTheme(ReaderTheme)
    case setFontDesign(ReaderFontDesign)
    case setTextScale(Double)
    case setPageLayout(ReaderPageLayout)
    case close
}

enum ReaderEffect: Sendable, Equatable {
    case close
}
