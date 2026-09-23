import Foundation
import Observation

@Observable
@MainActor
final class SeriesModel {
    private static let chapterOrderKey = RawSettingKey(
        "readr.series.chapterOrder",
        default: SeriesChapterOrder.newestFirst
    )

    private let id: SeriesID
    private let repository: any SeriesRepository
    private let library: any LibraryRepository
    private let catalog: any CatalogRepository
    private let settings: any SettingsStore
    private let effectContinuation: AsyncStream<SeriesEffect>.Continuation

    private var hasAppeared = false
    private var isLoading = false
    /// Bumped by every membership change, so a refresh that started before one
    /// cannot overwrite it with the membership it observed.
    private var membershipGeneration = 0
    private var isChangingMembership = false

    private(set) var state: SeriesState
    let effects: AsyncStream<SeriesEffect>

    init(
        id: SeriesID,
        repository: any SeriesRepository,
        library: any LibraryRepository,
        catalog: any CatalogRepository,
        settings: any SettingsStore
    ) {
        self.id = id
        self.repository = repository
        self.library = library
        self.catalog = catalog
        self.settings = settings

        let stream = AsyncStream.makeStream(of: SeriesEffect.self)
        effects = stream.stream
        effectContinuation = stream.continuation

        state = SeriesState(chapterOrder: settings.value(for: Self.chapterOrderKey))
    }

    deinit {
        effectContinuation.finish()
    }

    func onAction(_ action: SeriesAction) {
        switch action {
        case .appeared, .retry:
            handleLoading(action)
        case .toggleLibrary, .retryMembership, .dismissMembershipFailure, .dismissRefreshFailure:
            handleMembership(action)
        case .openChapter(let chapterID):
            openChapter(chapterID)
        case .continueReading:
            if let target = state.continueTarget {
                openChapter(target.id)
            }
        case .setRead, .markPreviousRead:
            handleReadState(action)
        case .selectChapterOrder(let order):
            state.chapterOrder = order
            settings.set(order, for: Self.chapterOrderKey)
        case .toggleSynopsis:
            state.isSynopsisExpanded.toggle()
        }
    }

    private func handleLoading(_ action: SeriesAction) {
        switch action {
        case .appeared:
            guard !hasAppeared else { return }
            hasAppeared = true
            Task { await load() }
        case .retry:
            Task { await load() }
        default:
            break
        }
    }

    private func handleMembership(_ action: SeriesAction) {
        switch action {
        case .toggleLibrary, .retryMembership:
            Task { await toggleLibrary() }
        case .dismissMembershipFailure:
            state.membershipFailure = nil
        case .dismissRefreshFailure:
            state.refreshFailure = nil
        default:
            break
        }
    }

    private func handleReadState(_ action: SeriesAction) {
        switch action {
        case .setRead(let ids, let isRead):
            Task { await setRead(ids, isRead: isRead) }
        case .markPreviousRead(let chapterID):
            guard let index = state.chapters.firstIndex(where: { $0.id == chapterID }) else {
                return
            }
            let previous = state.chapters[..<index].filter { !$0.isRead }.map(\.id)
            Task { await setRead(previous, isRead: true) }
        default:
            break
        }
    }

    /// Shows what is stored, then refreshes from the source.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        if state.series == nil {
            state.phase = .loading
        }
        await loadSourceName()

        do {
            if let snapshot = try await repository.stored(id) {
                apply(snapshot)
            } else if state.series == nil {
                state.series = try await repository.seed(for: id)
                state.isSaved = false
            }
            state.phase = .loaded
        } catch {
            if state.series == nil {
                state.phase = .failed(message: error.localizedDescription)
                return
            }
        }

        await refresh()
    }

    /// Fetches details and chapters from the source. Also the pull-to-refresh
    /// entry point, so it returns only when the refresh has finished.
    func refresh() async {
        guard let series = state.series, !state.isRefreshing else { return }
        state.isRefreshing = true
        state.refreshFailure = nil
        let generation = membershipGeneration

        do {
            let snapshot = try await repository.refresh(series)
            if generation == membershipGeneration {
                apply(snapshot)
            } else {
                // Membership changed mid-flight; what was fetched may already be
                // stored against the wrong membership. Re-read rather than guess.
                state.series = snapshot.series
                state.isRefreshing = false
                await refresh()
                return
            }
        } catch {
            state.refreshFailure = Self.message(for: error)
        }
        state.isRefreshing = false
    }

    private func loadSourceName() async {
        guard state.sourceName.isEmpty else { return }
        let sources = await catalog.sources()
        state.sourceName =
            sources.first(where: { $0.id == id.sourceID })?.name
            ?? "Source \(id.sourceID)"
    }

    private func apply(_ snapshot: SeriesSnapshot) {
        state.series = snapshot.series
        state.chapters = snapshot.chapters
        state.isSaved = snapshot.isSaved
        state.phase = .loaded
    }

    private func toggleLibrary() async {
        guard let series = state.series, !isChangingMembership else { return }
        isChangingMembership = true
        defer { isChangingMembership = false }

        let shouldBeSaved = !state.isSaved
        membershipGeneration += 1
        state.isSaved = shouldBeSaved
        state.membershipFailure = nil

        do {
            if shouldBeSaved {
                try await library.save(series)
                let chapters = state.chapters.map(\.chapter)
                if !chapters.isEmpty {
                    try await library.mergeChapterList(chapters, for: id)
                }
                if let snapshot = try await repository.stored(id) {
                    apply(snapshot)
                }
            } else {
                try await library.remove(id)
                // Reader state went with the series; what remains is the source's
                // listing, unread.
                let bySource = state.chapters.sorted { $0.sourceIndex < $1.sourceIndex }
                state.chapters = ChapterReadingOrder.sorted(
                    LibraryChapter.unsaved(bySource.map(\.chapter)))
            }
        } catch {
            state.isSaved = !shouldBeSaved
            state.membershipFailure =
                shouldBeSaved
                ? "Couldn’t add to your library. \(error.localizedDescription)"
                : "Couldn’t remove from your library. \(error.localizedDescription)"
        }
    }

    private func setRead(_ ids: [ChapterID], isRead: Bool) async {
        guard state.isSaved, !ids.isEmpty else { return }
        let targets = Set(ids)
        let previous = state.chapters
        state.chapters = state.chapters.map { chapter in
            guard targets.contains(chapter.id) else { return chapter }
            return LibraryChapter(
                chapter: chapter.chapter,
                isRead: isRead,
                readingPosition: isRead ? 1 : 0,
                lastReadAt: chapter.lastReadAt,
                sourceIndex: chapter.sourceIndex,
                isListedUpstream: chapter.isListedUpstream
            )
        }

        do {
            try await library.setRead(ids, isRead: isRead, in: id)
        } catch {
            state.chapters = previous
            state.refreshFailure = "Couldn’t update read state. \(error.localizedDescription)"
        }
    }

    private func openChapter(_ chapterID: ChapterID) {
        guard let series = state.series,
            state.chapters.contains(where: { $0.id == chapterID })
        else { return }
        effectContinuation.yield(
            .openReader(
                ReaderRoute(
                    sourceID: series.sourceID,
                    seriesURL: series.url,
                    chapterURL: chapterID.url,
                    contentType: series.contentType
                )))
    }

    private static func message(for error: any Error) -> String {
        if let error = error as? LibraryRepositoryError, case .emptyChapterList = error {
            return "The source returned no chapters. Your stored chapters are unchanged."
        }
        return "Couldn’t refresh. \(error.localizedDescription)"
    }
}
