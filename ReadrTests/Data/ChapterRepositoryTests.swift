import Foundation
import Testing

@testable import Readr

@Suite("DefaultChapterRepository")
struct ChapterRepositoryTests {
    private let source = SourceInfo(
        id: 7, name: "Source", lang: "en", baseURL: URL(string: "https://example.test")!,
        contentType: .manhwa)
    private let seriesURL = URL(string: "https://example.test/series/one")!
    private var id: SeriesID { SeriesID(sourceID: 7, url: seriesURL) }
    private var series: Series {
        Series(sourceID: 7, url: seriesURL, title: "One", contentType: .manhwa)
    }

    private func chapter(_ number: Int) -> Chapter {
        Chapter(
            sourceID: 7, seriesURL: seriesURL, url: seriesURL.appending(path: "c\(number)"),
            name: "Chapter \(number)", number: Double(number))
    }

    private struct Fixture {
        let repository: DefaultChapterRepository
        let library: InMemoryLibraryRepository
        let catalog: ScriptedCatalogRepository
        let downloads: FakeDownloadRepository
    }

    private func make(saved: Bool) -> Fixture {
        let library = InMemoryLibraryRepository(
            items: saved ? [LibraryItem(series: series, dateAdded: .now)] : [])
        let catalog = ScriptedCatalogRepository(sources: [source])
        let downloads = FakeDownloadRepository()
        return Fixture(
            repository: DefaultChapterRepository(
                library: library, catalog: catalog, downloads: downloads),
            library: library, catalog: catalog, downloads: downloads)
    }

    @Test("A saved series' chapters come from the library with reader state")
    func savedFromLibrary() async throws {
        let fixture = make(saved: true)
        let repository = fixture.repository
        let library = fixture.library
        let catalog = fixture.catalog
        try await library.mergeChapterList([chapter(2), chapter(1)], for: id)
        try await library.setRead([chapter(1).id], isRead: true, in: id)

        let chapters = try await repository.chapters(in: id, contentType: .manhwa)

        #expect(chapters.map(\.chapter.name) == ["Chapter 1", "Chapter 2"])
        #expect(chapters.map(\.isRead) == [true, false])
        #expect(await catalog.chapterCalls.isEmpty)
    }

    @Test("An unsaved series' chapters come from the catalog, unread, in reading order")
    func unsavedFromCatalog() async throws {
        let fixture = make(saved: false)
        let repository = fixture.repository
        let catalog = fixture.catalog
        await catalog.setChapters(.success([chapter(3), chapter(2), chapter(1)]), for: id)

        let chapters = try await repository.chapters(in: id, contentType: .manhwa)

        #expect(chapters.map(\.chapter.name) == ["Chapter 1", "Chapter 2", "Chapter 3"])
        #expect(chapters.allSatisfy { !$0.isRead })
        #expect(await catalog.refreshFlags == [false])
    }

    @Test("Content comes from the source")
    func contentFromSource() async throws {
        let fixture = make(saved: false)
        let repository = fixture.repository
        let catalog = fixture.catalog
        await catalog.setContent([.success(.pages(imageURLs: []))], for: chapter(1).id)

        let content = try await repository.content(for: chapter(1), bypassingStored: false)

        #expect(content == .pages(imageURLs: []))
        #expect(await catalog.contentCalls == [chapter(1).id])
    }

    @Test("Progress is stored for a saved series")
    func progressStored() async throws {
        let fixture = make(saved: true)
        let repository = fixture.repository
        let library = fixture.library
        try await library.mergeChapterList([chapter(1)], for: id)

        let recording = try await repository.recordProgress(
            chapter(1).id, in: id, position: 1, reachedEnd: true)

        #expect(recording == .stored)
        #expect(await library.storedChapter(chapter(1).id, in: id)?.isRead == true)
    }

    @Test("Progress for an unsaved series is reported, and nothing is written")
    func progressNotInLibrary() async throws {
        let fixture = make(saved: false)
        let repository = fixture.repository
        let library = fixture.library

        let recording = try await repository.recordProgress(
            chapter(1).id, in: id, position: 1, reachedEnd: true)

        #expect(recording == .notInLibrary)
        #expect(await library.progressCalls.isEmpty)
        #expect(await library.saveCalls.isEmpty)
    }

    @Test("Opening a chapter is recorded against a saved series only")
    func openRecorded() async throws {
        let saved = make(saved: true).repository
        let unsaved = make(saved: false).repository

        #expect(try await saved.recordOpened(in: id) == .stored)
        #expect(try await unsaved.recordOpened(in: id) == .notInLibrary)
    }

    @Test("A stored payload is served without a network request")
    func storedPayloadWins() async throws {
        let fixture = make(saved: true)
        let stored = ChapterContent.pages(imageURLs: [URL(fileURLWithPath: "/tmp/page-0001.jpg")])
        await fixture.downloads.store(stored, for: chapter(1).id)

        let content = try await fixture.repository.content(for: chapter(1), bypassingStored: false)

        #expect(content == stored)
        #expect(await fixture.catalog.contentCalls.isEmpty)
    }

    @Test("A forced fetch goes to the source even when a payload is stored")
    func bypassGoesToSource() async throws {
        let fixture = make(saved: true)
        let remote = ChapterContent.pages(imageURLs: [URL(string: "https://example.test/1.jpg")!])
        await fixture.downloads.store(.pages(imageURLs: []), for: chapter(1).id)
        await fixture.catalog.setContent([.success(remote)], for: chapter(1).id)

        let content = try await fixture.repository.content(for: chapter(1), bypassingStored: true)

        #expect(content == remote)
        #expect(await fixture.downloads.storedContentCalls.isEmpty)
    }

    @Test("The series lookup prefers the library, then the catalog listing")
    func seriesLookup() async {
        let saved = make(saved: true)
        #expect(await saved.repository.series(id, contentType: .manhwa).title == "One")

        let unsaved = make(saved: false)
        #expect(await unsaved.repository.series(id, contentType: .manhwa).hasBlankTitle)
    }
}
