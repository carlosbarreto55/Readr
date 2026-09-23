import Foundation
import Testing

@testable import Readr

@Suite("BrowseModel")
@MainActor
struct BrowseModelTests {
    private let source = SourceInfo(
        id: 7,
        name: "Example Source",
        lang: "en",
        baseURL: URL(string: "https://example.test")!,
        contentType: .novel
    )

    @Test("The Browse root loads registered sources and selection emits navigation")
    func sourceDiscoveryAndSelection() async {
        let catalog = FakeBrowseCatalogRepository(sources: [source])
        let model = BrowseModel(
            sourceID: nil,
            catalog: catalog,
            library: FakeBrowseLibraryRepository()
        )
        var effects = model.effects.makeAsyncIterator()

        model.onAction(.appeared)
        await waitUntil("sources to load") { !model.state.isLoading }

        #expect(model.state.sources == [source])
        #expect(model.state.items.isEmpty)

        model.onAction(.sourceSelected(source.id))
        #expect(await effects.next() == .openSource(source.id))
    }

    @Test("A source catalog opens Popular page 1 and marks saved identities")
    func initialCatalogAndMembership() async {
        let saved = series("saved")
        let other = series("other")
        let catalog = FakeBrowseCatalogRepository(sources: [source])
        await catalog.enqueue(
            .popular(page: 1),
            result: .success(SeriesPage(entries: [saved, other], hasMore: false))
        )
        let library = FakeBrowseLibraryRepository(items: [libraryItem(saved)])
        let model = BrowseModel(sourceID: source.id, catalog: catalog, library: library)

        model.onAction(.appeared)
        await waitUntil("the first popular page") { model.state.items.count == 2 }

        #expect(model.state.request == .popular)
        #expect(model.state.selectedSource == source)
        #expect(await catalog.operations() == [.popular(page: 1)])
        #expect(model.state.items.map(\.isSaved) == [true, false])
        #expect(model.state.items.map(\.sourceName) == [source.name, source.name])
    }

    @Test("A stale Popular response cannot replace a newer Latest catalog")
    func staleRequestCannotReplaceCurrentMode() async throws {
        let catalog = FakeBrowseCatalogRepository(sources: [source])
        await catalog.enqueue(
            .popular(page: 1),
            result: .success(SeriesPage(entries: [series("stale")], hasMore: false)),
            delay: .milliseconds(120)
        )
        await catalog.enqueue(
            .latest(page: 1),
            result: .success(SeriesPage(entries: [series("latest")], hasMore: false))
        )
        let model = BrowseModel(
            sourceID: source.id,
            catalog: catalog,
            library: FakeBrowseLibraryRepository()
        )

        model.onAction(.appeared)
        await waitUntil("Popular to start") {
            await catalog.operations().contains(.popular(page: 1))
        }
        model.onAction(.showLatest)
        await waitUntil("Latest to finish") {
            model.state.items.map(\.series.title) == ["latest"]
        }

        try await Task.sleep(for: .milliseconds(160))

        #expect(model.state.request == .latest)
        #expect(model.state.items.map(\.series.title) == ["latest"])
    }

    @Test("Clearing a submitted search restores the selected catalog on submit")
    func submittedSearchAndClearing() async {
        let catalog = FakeBrowseCatalogRepository(sources: [source])
        await catalog.enqueue(
            .popular(page: 1),
            result: .success(SeriesPage(entries: [series("first")], hasMore: false))
        )
        await catalog.enqueue(
            .latest(page: 1),
            result: .success(SeriesPage(entries: [series("latest")], hasMore: false))
        )
        await catalog.enqueue(
            .search(query: "moon", page: 1),
            result: .success(SeriesPage(entries: [series("result")], hasMore: false))
        )
        await catalog.enqueue(
            .latest(page: 1),
            result: .success(SeriesPage(entries: [series("restored")], hasMore: false))
        )
        let model = BrowseModel(
            sourceID: source.id,
            catalog: catalog,
            library: FakeBrowseLibraryRepository()
        )

        model.onAction(.appeared)
        await waitUntil("Popular to load") { model.state.items.first?.series.title == "first" }

        model.onAction(.showLatest)
        await waitUntil("Latest to load") { model.state.items.first?.series.title == "latest" }

        model.onAction(.searchTextChanged("  moon  "))
        model.onAction(.searchSubmitted)
        await waitUntil("Search to load") { model.state.items.first?.series.title == "result" }

        #expect(model.state.request == .search(query: "moon"))
        #expect(await catalog.operations().contains(.search(query: "moon", page: 1)))

        model.onAction(.searchTextChanged(""))
        #expect(model.state.request == .search(query: "moon"))
        model.onAction(.searchSubmitted)
        await waitUntil("Latest to reload") {
            model.state.items.first?.series.title == "restored"
        }

        #expect(model.state.request == .latest)
        #expect(
            await catalog.operations()
                == [
                    .popular(page: 1), .latest(page: 1),
                    .search(query: "moon", page: 1), .latest(page: 1)
                ]
        )
    }

    @Test("Load more appends uniquely, failure waits for retry, and retry repeats the page")
    func pagingFailureAndRetry() async {
        let first = series("first")
        let duplicate = series("duplicate")
        let final = series("final")
        let catalog = FakeBrowseCatalogRepository(sources: [source])
        await catalog.enqueue(
            .popular(page: 1),
            result: .success(SeriesPage(entries: [first, duplicate], hasMore: true))
        )
        await catalog.enqueue(.popular(page: 2), result: .failure)
        await catalog.enqueue(
            .popular(page: 2),
            result: .success(SeriesPage(entries: [duplicate, final], hasMore: false))
        )
        let model = BrowseModel(
            sourceID: source.id,
            catalog: catalog,
            library: FakeBrowseLibraryRepository()
        )

        model.onAction(.appeared)
        await waitUntil("page 1") { model.state.items.count == 2 }

        model.onAction(.loadMore)
        await waitUntil("page 2 failure") { model.state.errorMessage != nil }
        #expect(model.state.items.map(\.series.title) == ["first", "duplicate"])

        model.onAction(.loadMore)
        await Task.yield()
        #expect(await catalog.operations() == [.popular(page: 1), .popular(page: 2)])

        model.onAction(.retry)
        await waitUntil("page 2 retry") { model.state.items.count == 3 }

        #expect(model.state.items.map(\.series.title) == ["first", "duplicate", "final"])
        #expect(
            await catalog.operations()
                == [.popular(page: 1), .popular(page: 2), .popular(page: 2)]
        )
        #expect(model.state.hasMore == false)
    }

    @Test("Adding and removing are optimistic and persist through the repository")
    func optimisticAddAndRemove() async {
        let entry = series("entry")
        let catalog = await catalogReturning(entry)
        let library = FakeBrowseLibraryRepository()
        let model = BrowseModel(sourceID: source.id, catalog: catalog, library: library)
        var effects = model.effects.makeAsyncIterator()

        model.onAction(.appeared)
        await waitUntil("the catalog") { model.state.items.count == 1 }

        model.onAction(.toggleLibrary(entry))
        #expect(model.state.items.first?.isSaved == true)
        await waitUntil("save persistence") { await library.isSaved(entry.id) }

        model.onAction(.toggleLibrary(entry))
        #expect(model.state.items.first?.isSaved == false)
        await waitUntil("remove persistence") { !(await library.isSaved(entry.id)) }

        #expect(await library.saveCalls().map(\.id) == [entry.id])
        #expect(await library.removeCalls() == [entry.id])

        model.onAction(.openSeries(entry.id))
        #expect(await effects.next() == .openSeries(entry.id))
    }

    @Test("A failed membership write rolls back visibly and can be retried")
    func membershipFailureRollsBackAndRetries() async {
        let entry = series("entry")
        let catalog = await catalogReturning(entry)
        let library = FakeBrowseLibraryRepository()
        await library.makeNextSaveFail()
        let model = BrowseModel(sourceID: source.id, catalog: catalog, library: library)

        model.onAction(.appeared)
        await waitUntil("the catalog") { model.state.items.count == 1 }

        model.onAction(.toggleLibrary(entry))
        #expect(model.state.items.first?.isSaved == true)
        await waitUntil("save rollback") { model.state.membershipErrorMessage != nil }

        #expect(model.state.items.first?.isSaved == false)
        #expect(await library.isSaved(entry.id) == false)

        model.onAction(.retryMembership)
        #expect(model.state.items.first?.isSaved == true)
        await waitUntil("successful retry") { await library.isSaved(entry.id) }

        #expect(model.state.membershipErrorMessage == nil)
        #expect(await library.saveCalls().count == 2)
    }

    @Test("A failed membership load has a working retry")
    func membershipLoadRetry() async {
        let entry = series("entry")
        let catalog = await catalogReturning(entry)
        let library = FakeBrowseLibraryRepository(items: [libraryItem(entry)])
        await library.setSavedItemsShouldFail(true)
        let model = BrowseModel(sourceID: source.id, catalog: catalog, library: library)

        model.onAction(.appeared)
        await waitUntil("the catalog and membership failure") {
            model.state.items.count == 1 && model.state.membershipErrorMessage != nil
        }
        #expect(model.state.items.first?.isSaved == false)

        await library.setSavedItemsShouldFail(false)
        model.onAction(.retryMembership)
        await waitUntil("membership retry") { model.state.membershipErrorMessage == nil }

        #expect(model.state.items.first?.isSaved == true)
    }

    @Test("Returning to Browse refreshes membership changed by another tab")
    func membershipRefreshesAcrossTabs() async {
        let entry = series("entry")
        let catalog = await catalogReturning(entry)
        let library = FakeBrowseLibraryRepository()
        let model = BrowseModel(sourceID: source.id, catalog: catalog, library: library)

        model.onAction(.appeared)
        await waitUntil("the catalog") { model.state.items.count == 1 }
        #expect(model.state.items.first?.isSaved == false)

        try? await library.save(entry)
        model.onAction(.refreshMembership)
        await waitUntil("refreshed membership") { model.state.items.first?.isSaved == true }
    }
}

extension BrowseModelTests {
    @Test("A stale membership refresh cannot overwrite an optimistic mutation")
    func staleMembershipRefreshCannotOverwriteMutation() async throws {
        let entry = series("entry")
        let catalog = await catalogReturning(entry)
        let library = FakeBrowseLibraryRepository()
        let model = BrowseModel(sourceID: source.id, catalog: catalog, library: library)

        model.onAction(.appeared)
        await waitUntil("the catalog") { model.state.items.count == 1 }

        await library.setSavedItemsDelay(.milliseconds(120))
        model.onAction(.refreshMembership)
        await waitUntil("the refresh to start") { await library.savedItemsCalls() == 2 }

        model.onAction(.toggleLibrary(entry))
        #expect(model.state.items.first?.isSaved == true)
        await waitUntil("save persistence") { await library.isSaved(entry.id) }

        try await Task.sleep(for: .milliseconds(150))
        #expect(model.state.items.first?.isSaved == true)
        #expect(model.state.membershipErrorMessage == nil)
    }

    @Test("Initial membership loading cannot replace a newer catalog selection")
    func delayedInitialMembershipCannotReplaceSelection() async throws {
        let latest = series("latest")
        let catalog = FakeBrowseCatalogRepository(sources: [source])
        await catalog.enqueue(
            .latest(page: 1),
            result: .success(SeriesPage(entries: [latest], hasMore: false))
        )
        let library = FakeBrowseLibraryRepository()
        await library.setSavedItemsDelay(.milliseconds(120))
        let model = BrowseModel(sourceID: source.id, catalog: catalog, library: library)

        model.onAction(.appeared)
        await waitUntil("membership loading to start") { await library.savedItemsCalls() == 1 }
        model.onAction(.showLatest)
        await waitUntil("Latest to load") {
            model.state.items.first?.series.title == "latest"
        }

        try await Task.sleep(for: .milliseconds(150))
        #expect(model.state.request == .latest)
        #expect(model.state.items.map(\.series.title) == ["latest"])
        #expect(await catalog.operations() == [.latest(page: 1)])
    }
}

private extension BrowseModelTests {
    func catalogReturning(_ entry: Series) async -> FakeBrowseCatalogRepository {
        let catalog = FakeBrowseCatalogRepository(sources: [source])
        await catalog.enqueue(
            .popular(page: 1),
            result: .success(SeriesPage(entries: [entry], hasMore: false))
        )
        return catalog
    }

    func series(_ slug: String) -> Series {
        Series(
            sourceID: source.id,
            url: source.baseURL.appending(path: "series/\(slug)"),
            title: slug,
            contentType: source.contentType
        )
    }

    func libraryItem(_ series: Series) -> LibraryItem {
        LibraryItem(series: series, dateAdded: Date(timeIntervalSince1970: 1_000))
    }

    func waitUntil(
        _ description: String,
        condition: @escaping @MainActor () async -> Bool
    ) async {
        for _ in 0..<200 {
            if await condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Timed out waiting for \(description)")
    }
}
