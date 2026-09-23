import Foundation
import Testing

@testable import Readr

/// `spotlight-indexable-series` and the Spotlight half of
/// `library-search-via-spotlight`: the index follows the library, and a result is
/// checked against the library before it is opened.
@Suite("Spotlight projection and system search")
struct SystemSearchRepositoryTests {
    private let url = URL(string: "https://example.test/series/one")!

    private func series(_ title: String = "One", cover: URL? = nil) -> Series {
        Series(sourceID: 7, url: url, title: title, coverURL: cover, contentType: .novel)
    }

    private struct Fixture {
        let store: InMemoryLibraryRepository
        let library: ObservedLibraryRepository
        let indexer: RecordingIndexer
        let projection: SpotlightProjection
        let search: DefaultSystemSearchRepository
    }

    private func make(
        items: [LibraryItem] = [], cover: Data? = nil
    ) -> Fixture {
        let store = InMemoryLibraryRepository(items: items)
        let indexer = RecordingIndexer()
        let projection = SpotlightProjection(
            indexer: indexer,
            thumbnails: SpotlightThumbnailCache(
                directory: FileManager.default.temporaryDirectory
                    .appending(path: "readr-thumbs-\(UUID().uuidString)")),
            sourceName: { _ in "Source" },
            loadCover: { _ in cover },
            isSaved: { (try? await store.isSaved($0)) ?? false })
        return Fixture(
            store: store,
            library: ObservedLibraryRepository(base: store, observers: [projection]),
            indexer: indexer,
            projection: projection,
            search: DefaultSystemSearchRepository(library: store, projection: projection))
    }

    @Test("Saving a series indexes it under its (sourceID, url) identity")
    func saveIndexes() async throws {
        let fixture = make()
        try await fixture.library.save(series())

        let item = try #require(await fixture.indexer.items[series().id])
        #expect(item.title == "One")
        #expect(item.sourceName == "Source")
    }

    @Test("Changed metadata re-indexes the same item")
    func metadataUpdates() async throws {
        let fixture = make()
        try await fixture.library.save(series("Old"))
        try await fixture.library.save(series("New"))

        #expect(await fixture.indexer.items.count == 1)
        #expect(await fixture.indexer.items[series().id]?.title == "New")
    }

    @Test("Removing a series deletes its item")
    func removeDeletes() async throws {
        let fixture = make()
        try await fixture.library.save(series())
        try await fixture.library.remove(series().id)

        #expect(await fixture.indexer.items.isEmpty)
    }

    @Test("A cover is fetched once, stored locally, and re-indexed as a file URL")
    func thumbnailIsLocal() async throws {
        let fixture = make(cover: Data("jpeg".utf8))
        let saved = series(cover: URL(string: "https://cdn.test/cover.jpg")!)
        try await fixture.store.save(saved)

        await fixture.projection.index([saved])?.value

        let thumbnail = try #require(await fixture.indexer.items[saved.id]?.thumbnailURL)
        #expect(thumbnail.isFileURL)
        #expect(try Data(contentsOf: thumbnail) == Data("jpeg".utf8))
    }

    @Test("A series removed while its cover loads is not resurrected in the index")
    func removedDuringThumbnail() async throws {
        let fixture = make(cover: Data("jpeg".utf8))
        let unsaved = series(cover: URL(string: "https://cdn.test/cover.jpg")!)

        await fixture.projection.index([unsaved])?.value
        await fixture.projection.remove([unsaved.id])
        let indexCallsAfterRemoval = await fixture.indexer.indexCalls

        // The thumbnail pass saw it unsaved and indexed nothing further.
        #expect(await fixture.indexer.items.isEmpty)
        #expect(indexCallsAfterRemoval == 1)
    }

    @Test("A result for a saved series opens it")
    func resolveSaved() async throws {
        let fixture = make(items: [LibraryItem(series: series(), dateAdded: .now)])
        let resolution = await fixture.search.resolve(
            activityIdentifier: SpotlightIdentifier.make(for: series().id))
        #expect(resolution == .series(series().id))
    }

    @Test("A result for a removed series explains and removes the stale entry")
    func resolveStale() async throws {
        let fixture = make()
        await fixture.indexer.index([SpotlightAttributes.Item(series: series(), sourceName: "S")])

        let resolution = await fixture.search.resolve(
            activityIdentifier: SpotlightIdentifier.make(for: series().id))

        #expect(resolution == .noLongerSaved)
        #expect(await fixture.indexer.items.isEmpty)
    }

    @Test("A foreign identifier is ignored")
    func resolveForeign() async {
        #expect(await make().search.resolve(activityIdentifier: "elsewhere") == .unrecognized)
    }

    @Test("Rebuilding replaces the index with exactly the saved library")
    func rebuild() async throws {
        let other = Series(
            sourceID: 7, url: URL(string: "https://example.test/series/gone")!, title: "Gone",
            contentType: .novel)
        let fixture = make(items: [LibraryItem(series: series(), dateAdded: .now)])
        await fixture.indexer.index([SpotlightAttributes.Item(series: other, sourceName: "S")])

        await fixture.search.rebuildIndex()

        #expect(await fixture.indexer.removeAllCalls == 1)
        #expect(Array(await fixture.indexer.items.keys) == [series().id])
    }

    @Test("An unreadable library leaves the index alone")
    func rebuildWithUnreadableLibrary() async {
        let fixture = make(items: [LibraryItem(series: series(), dateAdded: .now)])
        await fixture.indexer.index([SpotlightAttributes.Item(series: series(), sourceName: "S")])
        await fixture.store.failing("savedItems")

        await fixture.search.rebuildIndex()

        #expect(await fixture.indexer.removeAllCalls == 0)
        #expect(await fixture.indexer.items.count == 1)
    }
}
