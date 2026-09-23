import Foundation
import Testing

@testable import Readr

@Suite("SeriesModel")
@MainActor
struct SeriesModelTests {
    private let source = SourceInfo(
        id: 7, name: "Comic Source", lang: "en", baseURL: URL(string: "https://example.test")!,
        contentType: .manhwa)
    private let seriesURL = URL(string: "https://example.test/series/one")!
    private var id: SeriesID { SeriesID(sourceID: 7, url: seriesURL) }

    private func series(_ title: String = "One") -> Series {
        Series(sourceID: 7, url: seriesURL, title: title, contentType: .manhwa)
    }

    private func chapter(_ number: Int) -> Chapter {
        Chapter(
            sourceID: 7, seriesURL: seriesURL, url: seriesURL.appending(path: "c\(number)"),
            name: "Chapter \(number)", number: Double(number))
    }

    private struct Fixture {
        let model: SeriesModel
        let library: InMemoryLibraryRepository
        let catalog: ScriptedCatalogRepository
        let settings: InMemorySettingsStore
        let downloads: FakeDownloadRepository
    }

    private func make(saved: Bool, settings: InMemorySettingsStore = .init()) -> Fixture {
        let library = InMemoryLibraryRepository(
            items: saved ? [LibraryItem(series: series(), dateAdded: .now)] : [])
        let catalog = ScriptedCatalogRepository(sources: [source])
        let downloads = FakeDownloadRepository()
        let repository = DefaultSeriesRepository(library: library, catalog: catalog)
        let model = SeriesModel(
            id: id, repository: repository, library: library, catalog: catalog,
            settings: settings, downloads: downloads)
        return Fixture(
            model: model, library: library, catalog: catalog, settings: settings,
            downloads: downloads)
    }

    @Test("A saved series shows its stored chapters, then refreshes them")
    func savedLoadsThenRefreshes() async throws {
        let fixture = make(saved: true)
        try await fixture.library.mergeChapterList([chapter(1)], for: id)
        try await fixture.library.setRead([chapter(1).id], isRead: true, in: id)
        await fixture.catalog.setChapters(.success([chapter(2), chapter(1)]), for: id)

        await fixture.model.load()

        let state = fixture.model.state
        #expect(state.phase == .loaded)
        #expect(state.isSaved)
        #expect(state.sourceName == "Comic Source")
        #expect(state.chapters.map(\.chapter.name) == ["Chapter 1", "Chapter 2"])
        #expect(state.chapters.map(\.isRead) == [true, false])
        #expect(state.continueTarget?.chapter.name == "Chapter 2")
        #expect(state.hasReadingHistory)
        #expect(!state.isRefreshing)
    }

    @Test("A failed refresh keeps stored content and reports the failure")
    func refreshFailureKeepsContent() async throws {
        let fixture = make(saved: true)
        try await fixture.library.mergeChapterList([chapter(1)], for: id)
        await fixture.catalog.setChapters(.failure(.failed), for: id)

        await fixture.model.load()

        #expect(fixture.model.state.phase == .loaded)
        #expect(fixture.model.state.chapters.count == 1)
        #expect(fixture.model.state.refreshFailure != nil)
    }

    @Test("An empty refresh says the stored chapters are unchanged")
    func emptyRefreshMessage() async throws {
        let fixture = make(saved: true)
        try await fixture.library.mergeChapterList([chapter(1)], for: id)
        await fixture.catalog.setChapters(.success([]), for: id)

        await fixture.model.load()

        #expect(fixture.model.state.refreshFailure?.contains("unchanged") == true)
        #expect(fixture.model.state.chapters.count == 1)
    }

    @Test("An unsaved series shows its seed, then remote chapters unread")
    func unsavedSeedsThenRefreshes() async {
        let fixture = make(saved: false)
        await fixture.catalog.setKnown(series("Listed Title"))
        await fixture.catalog.setChapters(.success([chapter(1)]), for: id)

        await fixture.model.load()

        #expect(fixture.model.state.series?.title == "Listed Title")
        #expect(!fixture.model.state.isSaved)
        #expect(fixture.model.state.chapters.map(\.isRead) == [false])
        #expect(!fixture.model.state.hasReadingHistory)
    }

    @Test("An unknown source with nothing stored fails with a retry")
    func unknownSourceFails() async {
        let library = InMemoryLibraryRepository()
        let catalog = ScriptedCatalogRepository(sources: [])
        let model = SeriesModel(
            id: id, repository: DefaultSeriesRepository(library: library, catalog: catalog),
            library: library, catalog: catalog, settings: InMemorySettingsStore(),
            downloads: FakeDownloadRepository())

        await model.load()

        guard case .failed = model.state.phase else {
            Issue.record("Expected a failed phase, got \(model.state.phase)")
            return
        }
    }

    @Test("Adding to the library saves the series and the chapters shown")
    func addStoresChapters() async throws {
        let fixture = make(saved: false)
        await fixture.catalog.setChapters(.success([chapter(1), chapter(2)]), for: id)
        await fixture.model.load()

        fixture.model.onAction(.toggleLibrary)
        try await waitUntil { fixture.model.state.isSaved }
        try await waitUntil { await fixture.library.mergeCalls.count == 1 }

        #expect(try await fixture.library.isSaved(id))
        #expect(try await fixture.library.libraryChapters(for: id).count == 2)
    }

    @Test("A failed add rolls back and reports")
    func addFailureRollsBack() async throws {
        let fixture = make(saved: false)
        await fixture.library.failing("save")
        await fixture.model.load()

        fixture.model.onAction(.toggleLibrary)
        try await waitUntil { fixture.model.state.membershipFailure != nil }

        #expect(!fixture.model.state.isSaved)
    }

    @Test("Removing from the library resets chapters to unread")
    func removeResetsState() async throws {
        let fixture = make(saved: true)
        try await fixture.library.mergeChapterList([chapter(1)], for: id)
        try await fixture.library.setRead([chapter(1).id], isRead: true, in: id)
        await fixture.catalog.setChapters(.success([chapter(1)]), for: id)
        await fixture.model.load()

        fixture.model.onAction(.toggleLibrary)
        try await waitUntil { !fixture.model.state.isSaved }

        #expect(fixture.model.state.chapters.map(\.isRead) == [false])
        #expect(try await fixture.library.isSaved(id) == false)
    }

    @Test("Marking read updates state and the library; previous chapters can be marked at once")
    func markRead() async throws {
        let fixture = make(saved: true)
        let chapters = [chapter(1), chapter(2), chapter(3)]
        try await fixture.library.mergeChapterList(chapters, for: id)
        await fixture.catalog.setChapters(.success(chapters), for: id)
        await fixture.model.load()

        fixture.model.onAction(.markPreviousRead(chapter(3).id))
        try await waitUntil { fixture.model.state.chapters.map(\.isRead) == [true, true, false] }
        #expect(await fixture.library.storedChapter(chapter(2).id, in: id)?.isRead == true)

        fixture.model.onAction(.setRead([chapter(1).id], isRead: false))
        try await waitUntil { fixture.model.state.chapters.first?.isRead == false }
        #expect(await fixture.library.storedChapter(chapter(1).id, in: id)?.isRead == false)
    }

    @Test("Opening a chapter emits a reader route carrying the series content type")
    func openEmitsRoute() async throws {
        let fixture = make(saved: true)
        try await fixture.library.mergeChapterList([chapter(1)], for: id)
        await fixture.catalog.setChapters(.success([chapter(1)]), for: id)
        await fixture.model.load()

        var iterator = fixture.model.effects.makeAsyncIterator()
        fixture.model.onAction(.continueReading)
        let effect = await iterator.next()

        #expect(
            effect
                == .openReader(
                    ReaderRoute(
                        sourceID: 7, seriesURL: seriesURL, chapterURL: chapter(1).url,
                        contentType: .manhwa)))
    }

    @Test("The chapter order choice persists and only changes presentation")
    func chapterOrderPersists() async throws {
        let settings = InMemorySettingsStore()
        let fixture = make(saved: true, settings: settings)
        try await fixture.library.mergeChapterList([chapter(1), chapter(2)], for: id)
        await fixture.catalog.setChapters(.success([chapter(1), chapter(2)]), for: id)
        await fixture.model.load()

        #expect(fixture.model.state.displayedChapters.map(\.chapter.name).first == "Chapter 2")
        fixture.model.onAction(.selectChapterOrder(.oldestFirst))
        #expect(fixture.model.state.displayedChapters.map(\.chapter.name).first == "Chapter 1")
        #expect(fixture.model.state.chapters.first?.chapter.name == "Chapter 1")

        let reopened = make(saved: true, settings: settings)
        #expect(reopened.model.state.chapterOrder == .oldestFirst)
    }

    @Test("Download All queues only chapters not already stored or queued")
    func downloadAll() async throws {
        let fixture = make(saved: true)
        let chapters = [chapter(1), chapter(2), chapter(3)]
        try await fixture.library.mergeChapterList(chapters, for: id)
        await fixture.catalog.setChapters(.success(chapters), for: id)
        await fixture.model.load()
        let observation = Task { await fixture.model.observeDownloads() }
        defer { observation.cancel() }

        await fixture.downloads.publish(
            DownloadQueueSnapshot(
                entries: [
                    DownloadEntry(
                        chapter: chapter(1), seriesTitle: "One", contentType: .manhwa,
                        state: .completed, enqueuedAt: .now)
                ],
                storageBytes: 1))
        try await waitUntil { fixture.model.state.downloadStates[chapter(1).id] == .completed }

        fixture.model.onAction(.downloadAll)
        try await waitUntil { await fixture.downloads.enqueued.count == 1 }

        let request = try #require(await fixture.downloads.enqueued.first)
        #expect(request.chapters == [chapter(2).id, chapter(3).id])
        #expect(request.seriesTitle == "One")
        #expect(request.contentType == .manhwa)
    }

    @Test("Per-chapter download actions reach the repository")
    func chapterDownloadActions() async throws {
        let fixture = make(saved: true)
        try await fixture.library.mergeChapterList([chapter(1)], for: id)
        await fixture.catalog.setChapters(.success([chapter(1)]), for: id)
        await fixture.model.load()

        fixture.model.onAction(.download([chapter(1).id]))
        fixture.model.onAction(.cancelDownload(chapter(1).id))
        fixture.model.onAction(.deleteDownload(chapter(1).id))

        try await waitUntil { await fixture.downloads.deleted == [chapter(1).id] }
        #expect(await fixture.downloads.enqueued.first?.chapters == [chapter(1).id])
        #expect(await fixture.downloads.cancelled == [chapter(1).id])
    }
}
