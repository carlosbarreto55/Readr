import Foundation
import Testing

@testable import Readr

private enum LibraryTestError: Error {
    case failed
    case unexpectedCatalogCall
}

private actor FakeLibraryRepository: LibraryRepository {
    private var storedItems: [LibraryItem]
    private var loadShouldFail = false
    private var removeShouldFail = false
    private var delayNextRemoval = false
    private var removalStarted = false
    private var removalStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var removalContinuation: CheckedContinuation<Void, Never>?

    init(items: [LibraryItem] = []) {
        storedItems = items
    }

    func setLoadShouldFail(_ shouldFail: Bool) {
        loadShouldFail = shouldFail
    }

    func prepareDelayedRemoval() {
        delayNextRemoval = true
        removalStarted = false
    }

    func waitForRemovalStart() async {
        guard !removalStarted else { return }
        await withCheckedContinuation { removalStartWaiters.append($0) }
    }

    func finishDelayedRemoval(failing: Bool) {
        removeShouldFail = failing
        removalContinuation?.resume()
        removalContinuation = nil
    }

    func savedItems() throws -> [LibraryItem] {
        if loadShouldFail { throw LibraryTestError.failed }
        return storedItems
    }

    func savedSeries() throws -> [Series] {
        if loadShouldFail { throw LibraryTestError.failed }
        return storedItems.map(\.series)
    }

    func series(_ id: SeriesID) -> Series? {
        storedItems.first(where: { $0.id == id })?.series
    }

    func isSaved(_ id: SeriesID) -> Bool {
        storedItems.contains(where: { $0.id == id })
    }

    func save(_ series: Series) {
        guard !storedItems.contains(where: { $0.id == series.id }) else { return }
        storedItems.append(LibraryItem(series: series, dateAdded: .now))
    }

    func remove(_ id: SeriesID) async throws {
        if delayNextRemoval {
            delayNextRemoval = false
            removalStarted = true
            let waiters = removalStartWaiters
            removalStartWaiters.removeAll()
            for waiter in waiters { waiter.resume() }
            await withCheckedContinuation { removalContinuation = $0 }
        }
        if removeShouldFail {
            removeShouldFail = false
            throw LibraryTestError.failed
        }
        storedItems.removeAll(where: { $0.id == id })
    }

    func chapters(for id: SeriesID) -> [Chapter] { [] }
    func libraryChapters(for id: SeriesID) -> [LibraryChapter] { [] }
    func storeChapters(_ chapters: [Chapter], for id: SeriesID) {}
    func mergeChapterList(_ chapters: [Chapter], for id: SeriesID) {}
    func setRead(_ chapterIDs: [ChapterID], isRead: Bool, in series: SeriesID) {}
    func recordProgress(
        _ chapter: ChapterID, in series: SeriesID, position: Double, reachedEnd: Bool, at date: Date
    ) {}
    func recordOpened(_ series: SeriesID, at date: Date) {}
}

private struct FakeCatalogRepository: CatalogRepository {
    let availableSources: [SourceInfo]

    func sources() async -> [SourceInfo] { availableSources }

    func popular(sourceID: Int64, page: Int, refresh: Bool) async throws -> SeriesPage {
        throw LibraryTestError.unexpectedCatalogCall
    }

    func latest(sourceID: Int64, page: Int, refresh: Bool) async throws -> SeriesPage {
        throw LibraryTestError.unexpectedCatalogCall
    }

    func search(
        sourceID: Int64,
        query: String,
        page: Int,
        filters: FilterList,
        refresh: Bool
    ) async throws -> SeriesPage {
        throw LibraryTestError.unexpectedCatalogCall
    }

    func details(for series: Series, refresh: Bool) async throws -> Series {
        throw LibraryTestError.unexpectedCatalogCall
    }

    func chapters(for series: Series, refresh: Bool) async throws -> [Chapter] {
        throw LibraryTestError.unexpectedCatalogCall
    }

    func chapterContent(for chapter: Chapter) async throws -> ChapterContent {
        throw LibraryTestError.unexpectedCatalogCall
    }
    func knownSeries(_ id: SeriesID) async -> Series? { nil }
    func supports(_ filter: Filter, sourceID: Int64) async -> Bool { false }
    func clearCaches() async {}
}

@Suite("LibraryModel")
@MainActor
struct LibraryModelTests {
    private let sourceOne = SourceInfo(
        id: 1,
        name: "Novel Source",
        lang: "en",
        baseURL: URL(string: "https://novel.test")!,
        contentType: .novel
    )
    private let sourceTwo = SourceInfo(
        id: 2,
        name: "Comic Source",
        lang: "en",
        baseURL: URL(string: "https://manhwa.test")!,
        contentType: .manhwa
    )

    @Test("Saved metadata loads without a remote catalog request")
    func loadsSavedMetadataOffline() async {
        let items = [
            item("Novel", sourceID: 1, type: .novel),
            item("Orphaned Source", sourceID: 99, type: .manhwa)
        ]
        let model = makeModel(items: items, sources: [sourceOne])

        await model.load()

        #expect(model.state.phase == .populated)
        #expect(model.state.items.map(\.series.title) == ["Novel", "Orphaned Source"])
        #expect(model.state.items.map(\.sourceName) == ["Novel Source", "Source 99"])
        #expect(model.state.sourceOptions.map(\.name) == ["Novel Source"])
    }

    @Test("An empty store and a failed store are different states, and retry recovers")
    func emptyErrorAndRetryStates() async {
        let repository = FakeLibraryRepository()
        await repository.setLoadShouldFail(true)
        let model = makeModel(repository: repository)

        await model.load()
        guard case .error = model.state.phase else {
            Issue.record("A failed store should render an error state")
            return
        }

        await repository.setLoadShouldFail(false)
        await model.load()
        #expect(model.state.phase == .empty)
    }

    @Test("Content and source filters never modify library membership")
    func filtersAndClear() async {
        let items = [
            item("Novel One", sourceID: 1, type: .novel),
            item("Novel Two", sourceID: 1, type: .novel),
            item("Manhwa", sourceID: 2, type: .manhwa)
        ]
        let model = makeModel(items: items, sources: [sourceOne, sourceTwo])
        await model.load()

        model.onAction(.selectContentFilter(.manhwa))
        #expect(model.state.items.map(\.series.title) == ["Manhwa"])

        model.onAction(.selectSource(1))
        #expect(model.state.phase == .filteredEmpty)
        #expect(model.state.items.isEmpty)

        model.onAction(.clearFilters)
        #expect(model.state.phase == .populated)
        #expect(model.state.items.count == 3)
        #expect(model.state.contentFilter == .all)
        #expect(model.state.selectedSourceID == nil)
    }

    @Test("Every sort is deterministic and unread series sort last")
    func deterministicSorts() async {
        let base = Date(timeIntervalSince1970: 1_000)
        let items = [
            item(
                "Zulu", sourceID: 1, type: .novel,
                dateAdded: base.addingTimeInterval(30),
                lastReadAt: base.addingTimeInterval(10)),
            item(
                "alpha", sourceID: 2, type: .manhwa,
                dateAdded: base.addingTimeInterval(20), lastReadAt: nil),
            item(
                "Bravo", sourceID: 1, type: .novel,
                dateAdded: base.addingTimeInterval(10),
                lastReadAt: base.addingTimeInterval(20))
        ]
        let model = makeModel(items: items, sources: [sourceOne, sourceTwo])
        await model.load()

        #expect(model.state.items.map(\.series.title) == ["Zulu", "alpha", "Bravo"])

        model.onAction(.selectSort(.title))
        #expect(model.state.items.map(\.series.title) == ["alpha", "Bravo", "Zulu"])

        model.onAction(.selectSort(.lastRead))
        #expect(model.state.items.map(\.series.title) == ["Bravo", "Zulu", "alpha"])
    }

    @Test("Filter and sort choices survive model reconstruction")
    func selectionsPersist() {
        let settings = InMemorySettingsStore()
        let first = makeModel(settings: settings)
        first.onAction(.selectContentFilter(.manhwa))
        first.onAction(.selectSource(2))
        first.onAction(.selectSort(.lastRead))

        let relaunched = makeModel(settings: settings)

        #expect(relaunched.state.contentFilter == .manhwa)
        #expect(relaunched.state.selectedSourceID == 2)
        #expect(relaunched.state.sort == .lastRead)
    }

    @Test("Manga filter selects manga alone and survives reconstruction")
    func mangaFilter() async {
        let settings = InMemorySettingsStore()
        let items = [
            item("Novel", sourceID: 1, type: .novel),
            item("Manhwa", sourceID: 2, type: .manhwa),
            item("Manga", sourceID: 3, type: .manga)
        ]
        let model = makeModel(items: items, settings: settings)
        await model.load()
        model.onAction(.selectContentFilter(.manga))
        #expect(model.state.items.map(\.series.title) == ["Manga"])
        #expect(makeModel(items: items, settings: settings).state.contentFilter == .manga)
    }

    @Test("A persisted source no longer registered resets to All Sources")
    func unavailableSourceSelectionResets() async {
        let settings = InMemorySettingsStore()
        let first = makeModel(settings: settings)
        first.onAction(.selectSource(404))

        let model = makeModel(
            items: [item("Saved", sourceID: 404, type: .novel)],
            sources: [sourceOne],
            settings: settings
        )
        await model.load()

        #expect(model.state.selectedSourceID == nil)
        #expect(model.state.items.map(\.series.title) == ["Saved"])

        let relaunched = makeModel(settings: settings)
        #expect(relaunched.state.selectedSourceID == nil)
    }

    @Test("Removal is optimistic and a persistence failure rolls it back")
    func removalRollsBackOnFailure() async {
        let saved = item("Saved", sourceID: 1, type: .novel)
        let repository = FakeLibraryRepository(items: [saved])
        await repository.prepareDelayedRemoval()
        let model = makeModel(repository: repository, sources: [sourceOne])
        await model.load()

        let removal = Task { await model.removeSeries(saved.id) }
        await repository.waitForRemovalStart()

        #expect(model.state.phase == .empty)
        #expect(model.state.items.isEmpty)

        await repository.finishDelayedRemoval(failing: true)
        await removal.value

        #expect(model.state.phase == .populated)
        #expect(model.state.items.map(\.series.title) == ["Saved"])
        #expect(model.state.removalFailure?.seriesID == saved.id)
    }

    @Test("Opening a card emits navigation without storing it in state")
    func openEmitsEffect() async {
        let saved = item("Saved", sourceID: 1, type: .novel)
        let model = makeModel(items: [saved])
        var effects = model.effects.makeAsyncIterator()

        model.onAction(.openSeries(saved.id))

        #expect(await effects.next() == .openSeries(saved.id))
    }

    @Test("Appearing again reloads membership changed by another tab")
    func reappearingReloadsMembership() async {
        let repository = FakeLibraryRepository()
        let model = makeModel(repository: repository, sources: [sourceOne])
        await model.load()
        #expect(model.state.phase == .empty)

        let added = item("Added in Browse", sourceID: 1, type: .novel)
        await repository.save(added.series)
        model.onAction(.appeared)

        for _ in 0..<100 where model.state.items.isEmpty {
            try? await Task.sleep(for: .milliseconds(5))
        }

        #expect(model.state.items.map(\.series.title) == ["Added in Browse"])
    }

    private func makeModel(
        items: [LibraryItem] = [],
        sources: [SourceInfo] = [],
        settings: InMemorySettingsStore = InMemorySettingsStore()
    ) -> LibraryModel {
        makeModel(
            repository: FakeLibraryRepository(items: items),
            sources: sources,
            settings: settings
        )
    }

    private func makeModel(
        repository: FakeLibraryRepository,
        sources: [SourceInfo] = [],
        settings: InMemorySettingsStore = InMemorySettingsStore(),
        refresher: any SeriesRepository = RecordingSeriesRepository()
    ) -> LibraryModel {
        LibraryModel(
            library: repository,
            catalog: FakeCatalogRepository(availableSources: sources),
            settings: settings,
            refresher: refresher
        )
    }

    private func item(
        _ title: String,
        sourceID: Int64,
        type: ContentType,
        dateAdded: Date = Date(timeIntervalSince1970: 1_000),
        lastReadAt: Date? = nil
    ) -> LibraryItem {
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        return LibraryItem(
            series: Series(
                sourceID: sourceID,
                url: URL(string: "https://example.test/\(sourceID)/\(encodedTitle)")!,
                title: title,
                contentType: type
            ),
            dateAdded: dateAdded,
            lastReadAt: lastReadAt
        )
    }
}
