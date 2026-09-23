import Foundation
import Observation

@Observable
@MainActor
final class ReaderModel {
    /// How far the position must move before it is written again. Coarse on
    /// purpose: a scroll produces a position per block, and the store needs one
    /// per few percent.
    static let persistThreshold = 0.05

    private let route: ReaderRoute
    private let repository: any ChapterRepository
    private let settings: any SettingsStore
    private let downloads: any DownloadRepository
    private let effectContinuation: AsyncStream<ReaderEffect>.Continuation

    private var hasAppeared = false
    private var loadToken = 0
    private var lastPersistedProgress: Double?
    private var hasReachedEnd = false
    /// Progress writes run one after another, so a late write can never land
    /// after — and overwrite — a newer one.
    private var persistTask: Task<Void, Never>?

    private(set) var state: ReaderState
    let effects: AsyncStream<ReaderEffect>

    init(
        route: ReaderRoute,
        repository: any ChapterRepository,
        settings: any SettingsStore,
        downloads: any DownloadRepository
    ) {
        self.route = route
        self.repository = repository
        self.settings = settings
        self.downloads = downloads

        let stream = AsyncStream.makeStream(of: ReaderEffect.self)
        effects = stream.stream
        effectContinuation = stream.continuation

        state = ReaderState(route: route, preferences: settings.readerPreferences)
    }

    deinit {
        effectContinuation.finish()
    }

    func onAction(_ action: ReaderAction) {
        switch action {
        case .appeared, .retry, .previousChapter, .nextChapter, .selectChapter, .close:
            handleNavigation(action)
        case .toggleControls, .showChapterList, .showSettings:
            handleChrome(action)
        case .positionChanged(let index):
            positionChanged(index)
        case .reachedEnd:
            reachedEnd()
        case .setTheme, .setFontDesign, .setTextScale, .setPageLayout:
            handlePreference(action)
        case .download:
            downloadCurrent()
        }
    }

    private func handleNavigation(_ action: ReaderAction) {
        switch action {
        case .appeared:
            guard !hasAppeared else { return }
            hasAppeared = true
            Task { await load() }
        case .retry:
            Task { await load() }
        case .previousChapter:
            openAdjacent(offset: -1)
        case .nextChapter:
            openAdjacent(offset: 1)
        case .selectChapter(let id):
            state.isChapterListPresented = false
            guard id != state.currentChapterID else { return }
            open(id)
        case .close:
            persistCurrent(force: true)
            effectContinuation.yield(.close)
        default:
            break
        }
    }

    private func handleChrome(_ action: ReaderAction) {
        switch action {
        case .toggleControls:
            state.controlsVisible.toggle()
        case .showChapterList(let isPresented):
            state.isChapterListPresented = isPresented
        case .showSettings(let isPresented):
            state.isSettingsPresented = isPresented
        default:
            break
        }
    }

    /// Loads the chapter list, then the current chapter.
    func load() async {
        let seriesID = SeriesID(sourceID: route.sourceID, url: route.seriesURL)
        if state.series == nil {
            state.series = await repository.series(seriesID, contentType: route.contentType)
        }
        if state.chapters.isEmpty {
            // A chapter list that fails to load costs previous/next and the list,
            // not the chapter the reader asked for.
            state.chapters =
                (try? await repository.chapters(in: seriesID, contentType: route.contentType))
                ?? []
        }
        await loadCurrentChapter()
    }

    /// Waits for every progress write issued so far.
    func flushProgress() async {
        await persistTask?.value
    }

    /// Opens the chapter `offset` places away in reading order, if there is one.
    private func openAdjacent(offset: Int) {
        guard let index = state.currentIndex, state.chapters.indices.contains(index + offset)
        else { return }
        open(state.chapters[index + offset].id)
    }

    private func open(_ id: ChapterID) {
        persistCurrent(force: true)
        state.currentChapterID = id
        Task { await loadCurrentChapter() }
    }

    private func loadCurrentChapter() async {
        loadToken += 1
        let token = loadToken
        let chapter = currentChapter()
        state.phase = .loading
        state.document = nil
        state.progress = 0
        lastPersistedProgress = nil
        hasReachedEnd = false

        do {
            let content = try await matchingContent(for: chapter)
            let document = await Self.makeDocument(content)
            guard token == loadToken else { return }

            let restored = restoredPosition(for: chapter.id)
            let lastIndex = max(document.length - 1, 0)
            state.initialIndex = min(Int((restored * Double(lastIndex)).rounded()), lastIndex)
            state.progress = restored
            state.document = document
            state.documentGeneration += 1
            state.phase = .loaded
            // Opening counts as reading: it stamps last-read, which is what the
            // Library's Last Read sort follows, and reveals whether progress is
            // kept at all.
            persist(position: restored, reachedEnd: false)
        } catch let failure as ReaderFailureError {
            guard token == loadToken else { return }
            state.phase = .failed(failure.failure)
        } catch {
            guard token == loadToken else { return }
            state.phase = .failed(
                ReaderFailure(
                    message: "Couldn’t load this chapter. \(error.localizedDescription)",
                    isRetryable: true))
        }
    }

    /// The chapter's content, provided it has the shape the route promised.
    ///
    /// One mismatch forces a fetch past anything stored; a second is an error.
    /// A mismatched payload is never rendered.
    private func matchingContent(for chapter: Chapter) async throws -> ChapterContent {
        let content = try await repository.content(for: chapter, bypassingStored: false)
        if content.contentType == route.contentType {
            return content
        }
        let forced = try await repository.content(for: chapter, bypassingStored: true)
        guard forced.contentType == route.contentType else {
            throw ReaderFailureError(
                failure: ReaderFailure(
                    message:
                        "This chapter returned \(Self.describe(forced.contentType)) where "
                        + "\(Self.describe(route.contentType)) was expected.",
                    isRetryable: true))
        }
        return forced
    }

    private func currentChapter() -> Chapter {
        state.currentChapter?.chapter
            ?? Chapter(
                sourceID: route.sourceID, seriesURL: route.seriesURL,
                url: state.currentChapterID.url, name: "")
    }

    /// A read chapter reopens at the start; anything else where it was left.
    private func restoredPosition(for id: ChapterID) -> Double {
        guard let stored = state.chapters.first(where: { $0.id == id }), !stored.isRead else {
            return 0
        }
        return min(max(stored.readingPosition, 0), 1)
    }

    private func positionChanged(_ index: Int) {
        guard let length = state.document?.length, length > 0 else { return }
        let lastIndex = max(length - 1, 1)
        state.progress = min(max(Double(index) / Double(lastIndex), 0), 1)
        persistCurrent(force: false)
    }

    private func reachedEnd() {
        guard state.phase == .loaded, !hasReachedEnd else { return }
        hasReachedEnd = true
        state.progress = 1
        persist(position: 1, reachedEnd: true)
    }

    private func persistCurrent(force: Bool) {
        guard state.phase == .loaded else { return }
        let moved = lastPersistedProgress.map { abs(state.progress - $0) } ?? 1
        guard force || moved >= Self.persistThreshold else { return }
        persist(position: state.progress, reachedEnd: hasReachedEnd)
    }

    private func persist(position: Double, reachedEnd: Bool) {
        lastPersistedProgress = position
        let chapterID = state.currentChapterID
        updateLocalChapter(chapterID, position: position, reachedEnd: reachedEnd)

        let repository = self.repository
        let seriesID = SeriesID(sourceID: route.sourceID, url: route.seriesURL)
        let previous = persistTask
        persistTask = Task { [weak self] in
            await previous?.value
            let recording = try? await repository.recordProgress(
                chapterID, in: seriesID, position: position, reachedEnd: reachedEnd)
            if recording == .notInLibrary {
                self?.state.isProgressStored = false
            }
        }
    }

    /// Keeps the in-memory list in step, so returning to a chapter restores it
    /// without re-reading the store.
    private func updateLocalChapter(_ id: ChapterID, position: Double, reachedEnd: Bool) {
        guard let index = state.chapters.firstIndex(where: { $0.id == id }) else { return }
        let chapter = state.chapters[index]
        state.chapters[index] = LibraryChapter(
            chapter: chapter.chapter,
            isRead: chapter.isRead || reachedEnd,
            readingPosition: position,
            lastReadAt: .now,
            sourceIndex: chapter.sourceIndex,
            isListedUpstream: chapter.isListedUpstream)
    }

}

// Appearance, downloads, and document building: separate from loading and
// progress above.
extension ReaderModel {

    private func handlePreference(_ action: ReaderAction) {
        switch action {
        case .setTheme(let theme):
            state.preferences.theme = theme
        case .setFontDesign(let design):
            state.preferences.fontDesign = design
        case .setTextScale(let scale):
            state.preferences.textScale = ReaderPreferences.clampedScale(scale)
        case .setPageLayout(let layout):
            state.preferences.pageLayout = layout
        default:
            return
        }
        settings.setReaderPreferences(state.preferences)
    }

    private func downloadCurrent() {
        guard let chapter = state.currentChapter?.chapter else { return }
        let downloads = self.downloads
        let title = state.seriesTitle
        let contentType = route.contentType
        Task {
            try? await downloads.enqueue(
                [chapter], seriesTitle: title, contentType: contentType)
        }
    }

    /// Follows this series' download state until cancelled; nothing polls.
    func observeDownloads() async {
        let seriesID = SeriesID(sourceID: route.sourceID, url: route.seriesURL)
        for await snapshot in await downloads.updates() {
            state.downloadStates = Dictionary(
                snapshot.entries.filter { $0.seriesID == seriesID }.map { ($0.id, $0.state) },
                uniquingKeysWith: { _, last in last })
        }
    }

    /// Parses text off the main actor; a long chapter is tens of thousands of
    /// nodes (invariant 7).
    nonisolated static func makeDocument(_ content: ChapterContent) async -> ReaderDocument {
        switch content {
        case .text(let html):
            let blocks = await Task.detached(priority: .userInitiated) {
                ChapterTextParser.parse(html)
            }.value
            return .text(blocks)
        case .pages(let urls):
            return .pages(urls)
        }
    }

    private static func describe(_ type: ContentType) -> String {
        type == .novel ? "text" : "page images"
    }
}

/// A load failure the model has already phrased for the reader.
private struct ReaderFailureError: Error {
    let failure: ReaderFailure
}
