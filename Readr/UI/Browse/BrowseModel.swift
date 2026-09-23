import Foundation
import Observation

/// Coordinates source discovery, paged catalogs, and library membership.
@Observable
@MainActor
final class BrowseModel {
    private enum BaseCatalog {
        case popular
        case latest

        var request: BrowseCatalogRequest {
            switch self {
            case .popular: .popular
            case .latest: .latest
            }
        }
    }

    private struct FailedMembershipMutation {
        let series: Series
        let shouldBeSaved: Bool
    }

    private let catalog: any CatalogRepository
    private let library: any LibraryRepository
    private let sourceID: Int64?
    private let effectContinuation: AsyncStream<BrowseEffect>.Continuation

    private var pager: CatalogPager?
    private var requestGeneration = 0
    private var membershipLoadGeneration = 0
    private var membershipRevision = 0
    private var membershipGenerations: [SeriesID: Int] = [:]
    private var pendingMembershipValues: [SeriesID: Bool] = [:]
    private var savedIDs: Set<SeriesID> = []
    private var failedMembershipMutation: FailedMembershipMutation?
    private var baseCatalog: BaseCatalog = .popular
    private var hasAppeared = false

    private(set) var state: BrowseState
    let effects: AsyncStream<BrowseEffect>

    init(
        sourceID: Int64?,
        catalog: any CatalogRepository,
        library: any LibraryRepository
    ) {
        self.sourceID = sourceID
        self.catalog = catalog
        self.library = library
        self.state = BrowseState(
            destination: sourceID.map(BrowseDestination.catalog(sourceID:)) ?? .sources
        )

        let stream = AsyncStream.makeStream(of: BrowseEffect.self)
        self.effects = stream.stream
        self.effectContinuation = stream.continuation
    }

    deinit {
        effectContinuation.finish()
    }

    func onAction(_ action: BrowseAction) {
        switch action {
        case .appeared, .sourceSelected, .openSeries:
            handleLifecycleOrNavigation(action)
        case .showPopular, .showLatest, .searchTextChanged, .searchSubmitted:
            handleCatalogSelection(action)
        case .retry, .loadMore:
            handlePaging(action)
        case .toggleLibrary, .refreshMembership, .retryMembership, .dismissMembershipError:
            handleMembership(action)
        }
    }

    private func handleLifecycleOrNavigation(_ action: BrowseAction) {
        switch action {
        case .appeared:
            guard !hasAppeared else { return }
            hasAppeared = true
            Task { await loadInitialState() }
        case .sourceSelected(let sourceID):
            effectContinuation.yield(.openSource(sourceID))
        case .openSeries(let id):
            effectContinuation.yield(.openSeries(id))
        default:
            break
        }
    }

    private func handleCatalogSelection(_ action: BrowseAction) {
        switch action {
        case .showPopular:
            guard sourceID != nil else { return }
            baseCatalog = .popular
            activate(.popular)
        case .showLatest:
            guard sourceID != nil else { return }
            baseCatalog = .latest
            activate(.latest)
        case .searchTextChanged(let query):
            state.searchText = query
        case .searchSubmitted:
            let query = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.isEmpty {
                activate(baseCatalog.request)
            } else {
                activate(.search(query: query))
            }
        default:
            break
        }
    }

    private func handlePaging(_ action: BrowseAction) {
        switch action {
        case .retry:
            retry()
        case .loadMore:
            loadMore()
        default:
            break
        }
    }

    private func handleMembership(_ action: BrowseAction) {
        switch action {
        case .toggleLibrary(let series):
            setMembership(for: series, shouldBeSaved: !savedIDs.contains(series.id))
        case .refreshMembership:
            guard sourceID != nil else { return }
            Task { await loadMembership() }
        case .retryMembership:
            if let mutation = failedMembershipMutation {
                setMembership(for: mutation.series, shouldBeSaved: mutation.shouldBeSaved)
            } else {
                Task { await loadMembership() }
            }
        case .dismissMembershipError:
            failedMembershipMutation = nil
            state.membershipErrorMessage = nil
        default:
            break
        }
    }

    private func loadInitialState() async {
        state.isLoading = true
        state.errorMessage = nil

        let sources = await catalog.sources()
        state.sources = sources

        guard let sourceID else {
            state.isLoading = false
            return
        }

        guard let selectedSource = sources.first(where: { $0.id == sourceID }) else {
            state.isLoading = false
            state.errorMessage = "This source is no longer available."
            return
        }
        state.selectedSource = selectedSource

        let initialRequestGeneration = requestGeneration
        await loadMembership()

        guard requestGeneration == initialRequestGeneration else { return }
        activate(.popular)
    }

    private func loadMembership() async {
        membershipLoadGeneration += 1
        let loadGeneration = membershipLoadGeneration
        let revision = membershipRevision

        do {
            let items = try await library.savedItems()
            guard loadGeneration == membershipLoadGeneration,
                revision == membershipRevision
            else { return }

            var loadedIDs = Set(items.map(\.id))
            for (id, shouldBeSaved) in pendingMembershipValues {
                if shouldBeSaved {
                    loadedIDs.insert(id)
                } else {
                    loadedIDs.remove(id)
                }
            }
            savedIDs = loadedIDs
            failedMembershipMutation = nil
            state.membershipErrorMessage = nil
            state.items = state.items.map { makeCardItem($0.series) }
        } catch {
            guard loadGeneration == membershipLoadGeneration,
                revision == membershipRevision
            else { return }

            failedMembershipMutation = nil
            state.membershipErrorMessage =
                "Couldn’t load library status. \(error.localizedDescription)"
        }
    }

    private func activate(_ request: BrowseCatalogRequest) {
        guard let sourceID else { return }

        requestGeneration += 1
        let generation = requestGeneration
        let repository = catalog
        let nextPager = CatalogPager { page in
            switch request {
            case .popular:
                try await repository.popular(
                    sourceID: sourceID, page: page, refresh: false)
            case .latest:
                try await repository.latest(
                    sourceID: sourceID, page: page, refresh: false)
            case .search(let query):
                try await repository.search(
                    sourceID: sourceID,
                    query: query,
                    page: page,
                    filters: .none,
                    refresh: false
                )
            }
        }

        pager = nextPager
        state.request = request
        state.items = []
        state.isLoading = true
        state.hasMore = true
        state.errorMessage = nil

        Task {
            await nextPager.loadFirstPage()
            accept(nextPager, generation: generation)
        }
    }

    private func retry() {
        guard let pager else {
            Task { await loadInitialState() }
            return
        }

        let generation = requestGeneration
        state.isLoading = true
        state.errorMessage = nil
        Task {
            await pager.retry()
            accept(pager, generation: generation)
        }
    }

    private func loadMore() {
        guard let pager,
            state.hasMore,
            !state.isLoading,
            state.errorMessage == nil
        else { return }

        let generation = requestGeneration
        state.isLoading = true
        Task {
            await pager.loadNextPage()
            accept(pager, generation: generation)
        }
    }

    private func accept(_ completedPager: CatalogPager, generation: Int) {
        guard generation == requestGeneration, pager === completedPager else { return }

        let pagerState = completedPager.state
        state.items = pagerState.entries.map(makeCardItem)
        state.isLoading = pagerState.isLoading
        state.hasMore = pagerState.hasMore
        state.errorMessage = pagerState.failure?.localizedDescription
    }
}

private extension BrowseModel {
    func makeCardItem(_ series: Series) -> SeriesCardItem {
        let sourceName =
            state.sources.first(where: { $0.id == series.sourceID })?.name
            ?? "Source \(series.sourceID)"
        return SeriesCardItem(
            series: series,
            sourceName: sourceName,
            isSaved: savedIDs.contains(series.id)
        )
    }

    func setMembership(for series: Series, shouldBeSaved: Bool) {
        let id = series.id
        let previousValue = savedIDs.contains(id)
        guard previousValue != shouldBeSaved else { return }

        membershipGenerations[id, default: 0] += 1
        let generation = membershipGenerations[id, default: 0]
        membershipRevision += 1
        pendingMembershipValues[id] = shouldBeSaved
        failedMembershipMutation = nil
        state.membershipErrorMessage = nil
        updateSavedID(id, isSaved: shouldBeSaved)

        Task {
            do {
                if shouldBeSaved {
                    try await library.save(series)
                } else {
                    try await library.remove(id)
                }
                guard membershipGenerations[id] == generation else { return }
                pendingMembershipValues[id] = nil
                membershipRevision += 1
            } catch {
                guard membershipGenerations[id] == generation else { return }
                pendingMembershipValues[id] = nil
                membershipRevision += 1
                updateSavedID(id, isSaved: previousValue)
                failedMembershipMutation = FailedMembershipMutation(
                    series: series,
                    shouldBeSaved: shouldBeSaved
                )
                state.membershipErrorMessage = error.localizedDescription
            }
        }
    }

    func updateSavedID(_ id: SeriesID, isSaved: Bool) {
        if isSaved {
            savedIDs.insert(id)
        } else {
            savedIDs.remove(id)
        }

        state.items = state.items.map { item in
            guard item.id == id else { return item }
            return SeriesCardItem(
                series: item.series,
                sourceName: item.sourceName,
                isSaved: isSaved
            )
        }
    }
}
