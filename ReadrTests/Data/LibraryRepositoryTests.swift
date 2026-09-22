import Foundation
import SwiftData
import Testing

@testable import Readr

@Suite("SwiftDataLibraryRepository")
struct LibraryRepositoryTests {
    private let seriesURL = URL(string: "https://example.test/series/one")!
    private let otherURL = URL(string: "https://example.test/series/two")!

    private func makeRepository() throws -> SwiftDataLibraryRepository {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: ReadrMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return SwiftDataLibraryRepository(modelContainer: container)
    }

    private func series(_ url: URL, title: String = "A Title") -> Series {
        Series(sourceID: 42, url: url, title: title, contentType: .novel)
    }

    private func chapter(
        _ path: String,
        name: String = "Chapter",
        number: Double? = nil
    ) -> Chapter {
        Chapter(
            sourceID: 42,
            seriesURL: seriesURL,
            url: URL(string: "https://example.test/series/one/\(path)")!,
            name: name,
            number: number
        )
    }

    @Test("A saved series reads back")
    func saveAndRead() async throws {
        let repository = try makeRepository()
        try await repository.save(series(seriesURL, title: "Saved"))

        #expect(try await repository.isSaved(SeriesID(sourceID: 42, url: seriesURL)))
        #expect(
            try await repository.series(SeriesID(sourceID: 42, url: seriesURL))?.title == "Saved")
        #expect(try await repository.savedSeries().count == 1)
    }

    @Test("An unsaved series is absent rather than an error")
    func unsavedIsAbsent() async throws {
        let repository = try makeRepository()
        #expect(try await repository.series(SeriesID(sourceID: 42, url: seriesURL)) == nil)
        #expect(try await repository.isSaved(SeriesID(sourceID: 42, url: seriesURL)) == false)
        #expect(try await repository.savedSeries().isEmpty)
    }

    @Test("Saving the same series twice does not duplicate it")
    func saveIsIdempotent() async throws {
        let repository = try makeRepository()
        try await repository.save(series(seriesURL))
        try await repository.save(series(seriesURL))
        #expect(try await repository.savedSeries().count == 1)
    }

    @Test("Saving again refreshes metadata without changing which series it is")
    func resaveUpdatesMetadata() async throws {
        let repository = try makeRepository()
        try await repository.save(series(seriesURL, title: "Original"))
        try await repository.save(series(seriesURL, title: "Retitled After Refresh"))

        let saved = try await repository.savedSeries()
        #expect(saved.count == 1)
        #expect(saved.first?.title == "Retitled After Refresh")
        #expect(saved.first?.id == SeriesID(sourceID: 42, url: seriesURL))
    }

    @Test("Saving again does not reset stored chapter state")
    func resavePreservesChapters() async throws {
        let repository = try makeRepository()
        let id = SeriesID(sourceID: 42, url: seriesURL)
        try await repository.save(series(seriesURL))
        try await repository.storeChapters([chapter("ch/1"), chapter("ch/2")], for: id)

        try await repository.save(series(seriesURL, title: "Refreshed"))

        #expect(try await repository.chapters(for: id).count == 2)
    }

    @Test("Removing a series takes its chapters with it")
    func removeCascades() async throws {
        let repository = try makeRepository()
        let id = SeriesID(sourceID: 42, url: seriesURL)
        try await repository.save(series(seriesURL))
        try await repository.storeChapters([chapter("ch/1"), chapter("ch/2")], for: id)

        try await repository.remove(id)

        #expect(try await repository.savedSeries().isEmpty)
        await #expect(throws: LibraryRepositoryError.seriesNotSaved(id)) {
            try await repository.chapters(for: id)
        }
    }

    @Test("Removing a series that is not saved is not an error")
    func removeUnsavedIsHarmless() async throws {
        let repository = try makeRepository()
        try await repository.remove(SeriesID(sourceID: 42, url: seriesURL))
        #expect(try await repository.savedSeries().isEmpty)
    }

    @Test("Removing one series leaves the others alone")
    func removeIsScoped() async throws {
        let repository = try makeRepository()
        try await repository.save(series(seriesURL))
        try await repository.save(series(otherURL))

        try await repository.remove(SeriesID(sourceID: 42, url: seriesURL))

        #expect(try await repository.savedSeries().map(\.url) == [otherURL])
    }

    @Test("Two sources may publish the same URL without colliding")
    func identityIncludesSourceID() async throws {
        let repository = try makeRepository()
        try await repository.save(
            Series(sourceID: 1, url: seriesURL, title: "One", contentType: .novel))
        try await repository.save(
            Series(sourceID: 2, url: seriesURL, title: "Two", contentType: .novel))

        #expect(try await repository.savedSeries().count == 2)
        #expect(try await repository.series(SeriesID(sourceID: 1, url: seriesURL))?.title == "One")
        #expect(try await repository.series(SeriesID(sourceID: 2, url: seriesURL))?.title == "Two")
    }

    @Test("Storing chapters against an unsaved series fails rather than inventing one")
    func storeChaptersRequiresSavedSeries() async throws {
        let repository = try makeRepository()
        let id = SeriesID(sourceID: 42, url: seriesURL)
        await #expect(throws: LibraryRepositoryError.seriesNotSaved(id)) {
            try await repository.storeChapters([chapter("ch/1")], for: id)
        }
    }

    @Test("Re-storing a chapter list updates metadata without duplicating chapters")
    func storeChaptersMerges() async throws {
        let repository = try makeRepository()
        let id = SeriesID(sourceID: 42, url: seriesURL)
        try await repository.save(series(seriesURL))
        try await repository.storeChapters([chapter("ch/1", name: "Ch. 1", number: 1)], for: id)

        // The same chapter, renumbered and renamed upstream, plus a new one.
        try await repository.storeChapters(
            [
                chapter("ch/1", name: "Ch. 01", number: 2),
                chapter("ch/2", name: "Ch. 02", number: 3)
            ],
            for: id
        )

        let stored = try await repository.chapters(for: id)
        #expect(stored.count == 2)
        #expect(stored.first(where: { $0.url.path().hasSuffix("ch/1") })?.name == "Ch. 01")
    }

    @Test("A chapter belonging to another series is rejected, not reparented")
    func storeChaptersRejectsForeignChapters() async throws {
        let repository = try makeRepository()
        let id = SeriesID(sourceID: 42, url: seriesURL)
        try await repository.save(series(seriesURL))
        try await repository.save(series(otherURL))

        // Right source, wrong series.
        let foreign = Chapter(
            sourceID: 42,
            seriesURL: otherURL,
            url: URL(string: "https://example.test/series/two/ch/1")!,
            name: "Belongs To Two"
        )
        await #expect(
            throws: LibraryRepositoryError.chapterNotInSeries(chapter: foreign.id, series: id)
        ) {
            try await repository.storeChapters([foreign], for: id)
        }

        // Right series, wrong source.
        let crossSource = Chapter(
            sourceID: 7,
            seriesURL: seriesURL,
            url: URL(string: "https://example.test/series/one/ch/1")!,
            name: "Belongs To Another Source"
        )
        await #expect(
            throws: LibraryRepositoryError.chapterNotInSeries(chapter: crossSource.id, series: id)
        ) {
            try await repository.storeChapters([crossSource], for: id)
        }

        #expect(try await repository.chapters(for: id).isEmpty)
    }

    @Test("A rejected batch writes nothing, not even its valid chapters")
    func storeChaptersRejectsTheWholeBatch() async throws {
        let repository = try makeRepository()
        let id = SeriesID(sourceID: 42, url: seriesURL)
        try await repository.save(series(seriesURL))

        let foreign = Chapter(
            sourceID: 42,
            seriesURL: otherURL,
            url: URL(string: "https://example.test/series/two/ch/9")!,
            name: "Foreign"
        )
        await #expect(throws: (any Error).self) {
            try await repository.storeChapters([chapter("ch/1"), foreign], for: id)
        }

        #expect(try await repository.chapters(for: id).isEmpty)
    }

    @Test("Saved series come back most recently added first")
    func savedSeriesIsOrderedByDateAddedDescending() async throws {
        let repository = try makeRepository()
        let third = URL(string: "https://example.test/series/three")!

        // `dateAdded` is set at insert, so the saves must be distinguishable in
        // time for the order to mean anything.
        try await repository.save(series(seriesURL, title: "First"))
        try await Task.sleep(for: .milliseconds(20))
        try await repository.save(series(otherURL, title: "Second"))
        try await Task.sleep(for: .milliseconds(20))
        try await repository.save(series(third, title: "Third"))

        #expect(try await repository.savedSeries().map(\.title) == ["Third", "Second", "First"])
    }
}
