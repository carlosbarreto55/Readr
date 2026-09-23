import Foundation
import Testing

@testable import Readr

@Suite("DefaultSeriesRepository")
struct SeriesRepositoryTests {
    private let source = SourceInfo(
        id: 7, name: "Source", lang: "en", baseURL: URL(string: "https://example.test")!,
        contentType: .manhwa)
    private let seriesURL = URL(string: "https://example.test/series/the-swordmaster")!
    private var id: SeriesID { SeriesID(sourceID: 7, url: seriesURL) }

    private func series(_ title: String = "The Swordmaster", synopsis: String? = nil) -> Series {
        Series(
            sourceID: 7, url: seriesURL, title: title, synopsis: synopsis, contentType: .manhwa)
    }

    private func chapter(_ number: Int) -> Chapter {
        Chapter(
            sourceID: 7, seriesURL: seriesURL, url: seriesURL.appending(path: "c\(number)"),
            name: "Chapter \(number)", number: Double(number))
    }

    private struct Fixture {
        let repository: DefaultSeriesRepository
        let library: InMemoryLibraryRepository
        let catalog: ScriptedCatalogRepository
    }

    private func make(saved: [Series] = []) -> Fixture {
        let library = InMemoryLibraryRepository(
            items: saved.map { LibraryItem(series: $0, dateAdded: .now) })
        let catalog = ScriptedCatalogRepository(sources: [source])
        return Fixture(
            repository: DefaultSeriesRepository(library: library, catalog: catalog),
            library: library, catalog: catalog)
    }

    @Test("A saved series is served from the library without touching the catalog")
    func storedIsLocal() async throws {
        let fixture = make(saved: [series()])
        let repository = fixture.repository
        let library = fixture.library
        let catalog = fixture.catalog
        try await library.mergeChapterList([chapter(2), chapter(1)], for: id)

        let snapshot = try #require(try await repository.stored(id))

        #expect(snapshot.isSaved)
        #expect(snapshot.chapters.map(\.chapter.name) == ["Chapter 1", "Chapter 2"])
        #expect(await catalog.detailCalls.isEmpty)
        #expect(await catalog.chapterCalls.isEmpty)
    }

    @Test("An unsaved series has no stored snapshot")
    func unsavedHasNoSnapshot() async throws {
        let fixture = make()
        let repository = fixture.repository
        #expect(try await repository.stored(id) == nil)
    }

    @Test("The seed prefers the library, then the catalog's listing, then a bare series")
    func seedFallbacks() async throws {
        let savedFixture = make(saved: [series("Saved")])
        let savedRepository = savedFixture.repository
        #expect(try await savedRepository.seed(for: id).title == "Saved")

        let listedFixture = make()
        let listedRepository = listedFixture.repository
        let catalog = listedFixture.catalog
        await catalog.setKnown(series("Listed"))
        #expect(try await listedRepository.seed(for: id).title == "Listed")

        let bareFixture = make()
        let bareRepository = bareFixture.repository
        let bare = try await bareRepository.seed(for: id)
        #expect(bare.id == id)
        #expect(bare.hasBlankTitle)
        #expect(bare.contentType == .manhwa)
        #expect(bare.displayTitle == "The Swordmaster")

        let unknown = SeriesID(sourceID: 999, url: seriesURL)
        await #expect(throws: CatalogRepositoryError.unknownSource(999)) {
            try await bareRepository.seed(for: unknown)
        }
    }

    @Test("Refreshing a saved series saves details, merges chapters, and keeps read state")
    func refreshSaved() async throws {
        let fixture = make(saved: [series()])
        let repository = fixture.repository
        let library = fixture.library
        let catalog = fixture.catalog
        try await library.mergeChapterList([chapter(1)], for: id)
        try await library.setRead([chapter(1).id], isRead: true, in: id)
        await catalog.setDetails(.success(series(synopsis: "Now with a synopsis")), for: id)
        await catalog.setChapters(.success([chapter(2), chapter(1)]), for: id)

        let snapshot = try await repository.refresh(series())

        #expect(snapshot.isSaved)
        #expect(snapshot.series.synopsis == "Now with a synopsis")
        #expect(snapshot.chapters.map(\.chapter.name) == ["Chapter 1", "Chapter 2"])
        #expect(snapshot.chapters.map(\.isRead) == [true, false])
        #expect(try await library.series(id)?.synopsis == "Now with a synopsis")
        #expect(await catalog.refreshFlags.allSatisfy { $0 })
    }

    @Test("Refreshing an unsaved series writes nothing")
    func refreshUnsaved() async throws {
        let fixture = make()
        let repository = fixture.repository
        let library = fixture.library
        let catalog = fixture.catalog
        await catalog.setChapters(.success([chapter(3), chapter(2), chapter(1)]), for: id)

        let snapshot = try await repository.refresh(series())

        #expect(!snapshot.isSaved)
        #expect(snapshot.chapters.map(\.chapter.name) == ["Chapter 1", "Chapter 2", "Chapter 3"])
        #expect(snapshot.chapters.allSatisfy { !$0.isRead })
        #expect(await library.saveCalls.isEmpty)
        #expect(await library.mergeCalls.isEmpty)
    }

    @Test("A refresh whose chapters fail leaves stored chapters as they were")
    func refreshFailureLeavesState() async throws {
        let fixture = make(saved: [series()])
        let repository = fixture.repository
        let library = fixture.library
        let catalog = fixture.catalog
        try await library.mergeChapterList([chapter(1)], for: id)
        await catalog.setChapters(.failure(.failed), for: id)

        await #expect(throws: FakeRepositoryError.failed) {
            try await repository.refresh(series())
        }
        #expect(try await library.libraryChapters(for: id).map(\.chapter.name) == ["Chapter 1"])
    }

    @Test("A refresh that parsed no title never blanks a stored one")
    func refreshNeverBlanksTitle() async throws {
        let fixture = make(saved: [series("Good Title")])
        let repository = fixture.repository
        let library = fixture.library
        let catalog = fixture.catalog
        await catalog.setDetails(.success(series("")), for: id)
        await catalog.setChapters(.success([chapter(1)]), for: id)

        _ = try await repository.refresh(series("Good Title"))

        #expect(try await library.series(id)?.title == "Good Title")
    }

    @Test("Library refresh repairs a blank title and merges chapters")
    func libraryRefreshRepairs() async throws {
        let fixture = make(saved: [series("")])
        let repository = fixture.repository
        let library = fixture.library
        let catalog = fixture.catalog
        await catalog.setDetails(.success(series("Repaired")), for: id)
        await catalog.setChapters(.success([chapter(1)]), for: id)

        let report = await repository.refreshLibrary()

        #expect(report == LibraryRefreshReport(refreshed: 1, failed: 0, repairedTitles: 1))
        #expect(try await library.series(id)?.title == "Repaired")
        #expect(try await library.libraryChapters(for: id).count == 1)
    }

    @Test("A failed repair keeps the series saved and blank, to be retried next time")
    func failedRepairRetried() async throws {
        let fixture = make(saved: [series("")])
        let repository = fixture.repository
        let library = fixture.library
        let catalog = fixture.catalog
        await catalog.setDetails(.failure(.failed), for: id)

        let first = await repository.refreshLibrary()
        #expect(first == LibraryRefreshReport(refreshed: 0, failed: 1, repairedTitles: 0))
        #expect(try await library.isSaved(id))
        #expect(try await library.series(id)?.hasBlankTitle == true)

        await catalog.setDetails(.success(series("Second Try")), for: id)
        await catalog.setChapters(.success([chapter(1)]), for: id)
        let second = await repository.refreshLibrary()
        #expect(second.repairedTitles == 1)
        #expect(await catalog.detailCalls.count == 2)
    }

    @Test("A repair that still yields no title keeps the series with its placeholder")
    func repairWithoutTitle() async throws {
        let fixture = make(saved: [series("")])
        let repository = fixture.repository
        let library = fixture.library
        let catalog = fixture.catalog
        await catalog.setDetails(.success(series("   ")), for: id)
        await catalog.setChapters(.success([chapter(1)]), for: id)

        let report = await repository.refreshLibrary()

        #expect(report == LibraryRefreshReport(refreshed: 1, failed: 0, repairedTitles: 0))
        let stored = try #require(try await library.series(id))
        #expect(stored.hasBlankTitle)
        #expect(stored.displayTitle == "The Swordmaster")
    }

    @Test("A titled series is not re-fetched for details by a library refresh")
    func titledSkipsDetails() async throws {
        let fixture = make(saved: [series()])
        let repository = fixture.repository
        let catalog = fixture.catalog
        await catalog.setChapters(.success([chapter(1)]), for: id)

        _ = await repository.refreshLibrary()

        #expect(await catalog.detailCalls.isEmpty)
        #expect(await catalog.chapterCalls == [id])
    }

    @Test("One failing series does not stop the rest")
    func failuresAreIsolated() async throws {
        let otherURL = URL(string: "https://example.test/series/other")!
        let other = Series(sourceID: 7, url: otherURL, title: "Other", contentType: .manhwa)
        let fixture = make(saved: [series(), other])
        let repository = fixture.repository
        let library = fixture.library
        let catalog = fixture.catalog
        await catalog.setChapters(.failure(.failed), for: id)
        await catalog.setChapters(
            .success([
                Chapter(
                    sourceID: 7, seriesURL: otherURL, url: otherURL.appending(path: "1"),
                    name: "One")
            ]),
            for: other.id)

        let report = await repository.refreshLibrary()

        #expect(report.refreshed == 1)
        #expect(report.failed == 1)
        #expect(try await library.libraryChapters(for: other.id).count == 1)
    }
}
