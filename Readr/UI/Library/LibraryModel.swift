import Foundation
import Observation

@Observable
@MainActor
final class LibraryModel {
    private static let contentFilterKey = RawSettingKey(
        "readr.library.contentFilter",
        default: LibraryContentFilter.all
    )
    private static let sourceIDKey = SettingKey(
        "readr.library.sourceID",
        default: ""
    )
    private static let sortKey = RawSettingKey(
        "readr.library.sort",
        default: LibrarySort.dateAdded
    )

    private let library: any LibraryRepository
    private let catalog: any CatalogRepository
    private let settings: any SettingsStore
    private let refresher: any SeriesRepository
    private let effectContinuation: AsyncStream<LibraryEffect>.Continuation

    private var allItems: [LibraryItem] = []
    private var sourceNames: [Int64: String] = [:]
    private var isLoading = false
    private var removingIDs: Set<SeriesID> = []

    private(set) var state: LibraryState
    let effects: AsyncStream<LibraryEffect>

    init(
        library: any LibraryRepository,
        catalog: any CatalogRepository,
        settings: any SettingsStore,
        refresher: any SeriesRepository
    ) {
        self.library = library
        self.catalog = catalog
        self.settings = settings
        self.refresher = refresher

        let stream = AsyncStream.makeStream(of: LibraryEffect.self)
        effects = stream.stream
        effectContinuation = stream.continuation

        state = LibraryState(
            contentFilter: settings.value(for: Self.contentFilterKey),
            selectedSourceID: Int64(settings.value(for: Self.sourceIDKey)),
            sort: settings.value(for: Self.sortKey)
        )
    }

    deinit {
        effectContinuation.finish()
    }

    func onAction(_ action: LibraryAction) {
        switch action {
        case .appeared:
            Task { await load() }
        case .retry:
            Task { await load() }
        case .selectContentFilter(let filter):
            state.contentFilter = filter
            settings.set(filter, for: Self.contentFilterKey)
            rebuildVisibleItems()
        case .selectSource(let sourceID):
            state.selectedSourceID = sourceID
            settings.set(sourceID.map(String.init) ?? "", for: Self.sourceIDKey)
            rebuildVisibleItems()
        case .selectSort(let sort):
            state.sort = sort
            settings.set(sort, for: Self.sortKey)
            rebuildVisibleItems()
        case .clearFilters:
            state.contentFilter = .all
            state.selectedSourceID = nil
            settings.set(.all, for: Self.contentFilterKey)
            settings.set("", for: Self.sourceIDKey)
            rebuildVisibleItems()
        case .openSeries(let id):
            effectContinuation.yield(.openSeries(id))
        case .removeSeries(let id), .retryRemoval(let id):
            Task { await removeSeries(id) }
        case .dismissRemovalFailure:
            state.removalFailure = nil
        }
    }

    /// Pull-to-refresh: refreshes every saved series from its source — which is
    /// also what repairs blank titles — then reloads what is stored. Returns when
    /// both have finished, so the system spinner is honest.
    func refreshLibrary() async {
        _ = await refresher.refreshLibrary()
        await load(showingProgress: false)
    }

    /// - Parameter showingProgress: `false` reloads in place, keeping the grid on
    ///   screen, for reloads the reader did not ask to watch.
    func load(showingProgress: Bool = true) async {
        guard !isLoading else { return }
        isLoading = true
        if showingProgress || state.items.isEmpty {
            state.phase = .loading
        }
        state.removalFailure = nil

        let sources = await catalog.sources()
        do {
            allItems = try await library.savedItems()
            sourceNames = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0.name) })
            state.sourceOptions =
                sources
                .map { LibrarySourceOption(id: $0.id, name: $0.name) }
                .sorted(by: sourceOptionPrecedes)

            let selectedSourceIsUnavailable =
                state.selectedSourceID.map {
                    sourceNames[$0] == nil
                } ?? false
            if selectedSourceIsUnavailable {
                state.selectedSourceID = nil
                settings.set("", for: Self.sourceIDKey)
            }

            rebuildVisibleItems()
        } catch {
            state.items = []
            state.phase = .error(
                message: "Couldn’t load your library. \(error.localizedDescription)"
            )
        }

        isLoading = false
    }

    func removeSeries(_ id: SeriesID) async {
        guard removingIDs.insert(id).inserted,
            let index = allItems.firstIndex(where: { $0.id == id })
        else { return }

        let removed = allItems.remove(at: index)
        state.removalFailure = nil
        rebuildVisibleItems()

        do {
            try await library.remove(id)
        } catch {
            if !allItems.contains(where: { $0.id == id }) {
                allItems.insert(removed, at: min(index, allItems.endIndex))
            }
            state.removalFailure = LibraryRemovalFailure(
                seriesID: id,
                title: removed.series.displayTitle,
                message: error.localizedDescription
            )
            rebuildVisibleItems()
        }

        removingIDs.remove(id)
    }

    private func rebuildVisibleItems() {
        guard !allItems.isEmpty else {
            state.items = []
            state.phase = .empty
            return
        }

        let filtered = allItems.filter { item in
            state.contentFilter.includes(item.series.contentType)
                && (state.selectedSourceID.map { $0 == item.series.sourceID } ?? true)
        }
        let sorted = filtered.sorted(by: itemPrecedes)

        state.items = sorted.map { item in
            SeriesCardItem(
                series: item.series,
                sourceName: sourceNames[item.series.sourceID]
                    ?? "Source \(item.series.sourceID)",
                isSaved: true
            )
        }
        state.phase = state.items.isEmpty ? .filteredEmpty : .populated
    }

    private func itemPrecedes(_ lhs: LibraryItem, _ rhs: LibraryItem) -> Bool {
        switch state.sort {
        case .title:
            return titleOrIdentityPrecedes(lhs, rhs)
        case .dateAdded:
            if lhs.dateAdded != rhs.dateAdded {
                return lhs.dateAdded > rhs.dateAdded
            }
            return titleOrIdentityPrecedes(lhs, rhs)
        case .lastRead:
            switch (lhs.lastReadAt, rhs.lastReadAt) {
            case (.some(let left), .some(let right)) where left != right:
                return left > right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return titleOrIdentityPrecedes(lhs, rhs)
            }
        }
    }

    private func titleOrIdentityPrecedes(_ lhs: LibraryItem, _ rhs: LibraryItem) -> Bool {
        // The displayed title, so a blank-titled series sorts where its
        // placeholder label says it is.
        let leftTitle = normalizedTitle(lhs.series.displayTitle)
        let rightTitle = normalizedTitle(rhs.series.displayTitle)
        if leftTitle != rightTitle { return leftTitle < rightTitle }
        if lhs.series.displayTitle != rhs.series.displayTitle {
            return lhs.series.displayTitle < rhs.series.displayTitle
        }
        if lhs.series.sourceID != rhs.series.sourceID {
            return lhs.series.sourceID < rhs.series.sourceID
        }
        return lhs.series.url.absoluteString < rhs.series.url.absoluteString
    }

    private func normalizedTitle(_ title: String) -> String {
        title.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private func sourceOptionPrecedes(
        _ lhs: LibrarySourceOption,
        _ rhs: LibrarySourceOption
    ) -> Bool {
        let leftName = normalizedTitle(lhs.name)
        let rightName = normalizedTitle(rhs.name)
        if leftName != rightName { return leftName < rightName }
        return lhs.id < rhs.id
    }
}
