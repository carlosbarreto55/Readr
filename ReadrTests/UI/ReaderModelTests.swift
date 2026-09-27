import Foundation
import Testing

@testable import Readr

@Suite("ReaderModel")
@MainActor
struct ReaderModelTests {
    private let seriesURL = URL(string: "https://example.test/series")!

    private func chapter(
        _ number: Int, isRead: Bool = false, position: Double = 0
    ) -> LibraryChapter {
        LibraryChapter(
            chapter: Chapter(
                sourceID: 1, seriesURL: seriesURL, url: seriesURL.appending(path: "\(number)"),
                name: "Chapter \(number)", number: Double(number)),
            isRead: isRead, readingPosition: position, sourceIndex: number)
    }

    private func route(_ number: Int, _ type: ContentType) -> ReaderRoute {
        ReaderRoute(
            sourceID: 1, seriesURL: seriesURL, chapterURL: seriesURL.appending(path: "\(number)"),
            contentType: type)
    }

    private func pages(_ count: Int) -> ChapterContent {
        .pages(imageURLs: (0..<count).map { URL(string: "https://example.test/p/\($0).jpg")! })
    }

    private func make(
        _ route: ReaderRoute, repository: FakeChapterRepository,
        settings: InMemorySettingsStore = .init(),
        downloads: FakeDownloadRepository = FakeDownloadRepository()
    ) -> ReaderModel {
        ReaderModel(
            route: route, repository: repository, settings: settings, downloads: downloads)
    }

    @Test("Text content is parsed into blocks and shown")
    func loadsText() async {
        let repository = FakeChapterRepository(chapters: [chapter(1)])
        await repository.script([.text(html: "<p>One.</p><p>Two.</p>")], for: chapter(1).id)
        let model = make(route(1, .novel), repository: repository)

        await model.load()

        #expect(model.state.phase == .loaded)
        guard case .text(let blocks) = model.state.document else {
            Issue.record("Expected text, got \(String(describing: model.state.document))")
            return
        }
        #expect(blocks.map(\.plainText) == ["One.", "Two."])
        #expect(model.state.chapterTitle == "Chapter 1")
    }

    @Test("Page content is shown in reading order")
    func loadsPages() async {
        let repository = FakeChapterRepository(chapters: [chapter(1)])
        await repository.script([pages(3)], for: chapter(1).id)
        let model = make(route(1, .manhwa), repository: repository)

        await model.load()

        #expect(model.state.document == .pages(pages(3).imageURLs))
    }

    @Test(
        "Manga and comics restore their logical page index and keep a separate layout",
        arguments: [ContentType.manga, .comic])
    func pagedTypePositionAndLayout(type: ContentType) async {
        let repository = FakeChapterRepository(chapters: [chapter(1, position: 0.4)])
        await repository.script([pages(11)], for: chapter(1).id)
        let settings = InMemorySettingsStore()
        settings.setReaderPreferences(ReaderPreferences(pageLayout: .paged))
        let model = make(route(1, type), repository: repository, settings: settings)
        await model.load()

        #expect(model.state.document == .pages(pages(11).imageURLs))
        #expect(model.state.initialIndex == 4)
        #expect(model.state.preferences.pageLayout(for: type) == .paged)
        model.onAction(.positionChanged(index: 5))
        await model.flushProgress()
        #expect(model.state.progress == 0.5)

        model.onAction(.setPageLayout(.vertical))
        let stored = settings.readerPreferences
        #expect(stored.pageLayout(for: type) == .vertical)
        #expect(stored.pageLayout == .paged)
        let other: ContentType = type == .manga ? .comic : .manga
        #expect(stored.pageLayout(for: other) == .paged)
    }

    @Test("A mismatched payload forces one fetch past stored content and is never shown")
    func mismatchForcesFetch() async {
        let repository = FakeChapterRepository(chapters: [chapter(1)])
        await repository.script([.text(html: "<p>wrong</p>"), pages(2)], for: chapter(1).id)
        let model = make(route(1, .manhwa), repository: repository)

        await model.load()

        #expect(await repository.bypassFlags() == [false, true])
        #expect(model.state.document == .pages(pages(2).imageURLs))
    }

    @Test("A second mismatch is a retryable unexpected-content error")
    func secondMismatchFails() async {
        let repository = FakeChapterRepository(chapters: [chapter(1)])
        await repository.script([.text(html: "<p>wrong</p>")], for: chapter(1).id)
        let model = make(route(1, .manhwa), repository: repository)

        await model.load()

        guard case .failed(let failure) = model.state.phase else {
            Issue.record("Expected failure, got \(model.state.phase)")
            return
        }
        #expect(failure.isRetryable)
        #expect(model.state.document == nil)
        #expect(await repository.bypassFlags() == [false, true])
    }

    @Test("Previous is disabled, not absent, at the first chapter; next opens the next")
    func chapterNavigation() async throws {
        let repository = FakeChapterRepository(chapters: [chapter(1), chapter(2)])
        await repository.script([pages(2)], for: chapter(1).id)
        await repository.script([pages(4)], for: chapter(2).id)
        let model = make(route(1, .manhwa), repository: repository)
        await model.load()

        #expect(!model.state.hasPrevious)
        #expect(model.state.hasNext)

        model.onAction(.nextChapter)
        try await waitUntil { model.state.document == .pages(pages(4).imageURLs) }

        #expect(model.state.chapterTitle == "Chapter 2")
        #expect(model.state.hasPrevious)
        #expect(!model.state.hasNext)
    }

    @Test("Position is written coarsely as the reader moves, and on close")
    func progressIsCoarse() async throws {
        let repository = FakeChapterRepository(chapters: [chapter(1)])
        await repository.script([pages(101)], for: chapter(1).id)
        let model = make(route(1, .manhwa), repository: repository)
        await model.load()

        model.onAction(.positionChanged(index: 1))  // 1% — below the threshold
        model.onAction(.positionChanged(index: 10))  // 10%
        model.onAction(.positionChanged(index: 12))  // 12% — below again
        model.onAction(.close)
        await model.flushProgress()

        // 10%, and the forced write on close at 12%. Opening writes no progress.
        #expect(await repository.progressPositions() == [0.1, 0.12])
        #expect(await repository.opens == 1)
        #expect(abs(model.state.progress - 0.12) < 0.0001)
    }

    @Test("Reporting the same position again changes nothing and writes nothing")
    func repeatedPositionIsIgnored() async {
        let repository = FakeChapterRepository(chapters: [chapter(1)])
        await repository.script([pages(101)], for: chapter(1).id)
        let model = make(route(1, .manhwa), repository: repository)
        await model.load()

        model.onAction(.positionChanged(index: 20))
        model.onAction(.positionChanged(index: 20))
        model.onAction(.positionChanged(index: 20))
        await model.flushProgress()

        #expect(await repository.progressPositions() == [0.2])
        #expect(model.state.progress == 0.2)
    }

    @Test("The reading position among visible pages is the earliest")
    func firstVisiblePage() {
        #expect(PageRenderer.firstVisible([4, 2, 3]) == 2)
        #expect(PageRenderer.firstVisible([]) == nil)
    }

    @Test("Tall pages are cut into drawable strips that cover the whole image")
    func pageTiles() {
        let strip = PageTiles.rects(width: 900, height: 16_000)
        #expect(strip.count == 8)
        #expect(strip.allSatisfy { $0.height <= CGFloat(PageTiles.maxTileHeight) })
        #expect(strip.reduce(0) { $0 + $1.height } == 16_000)
        #expect(strip.last?.maxY == 16_000)

        #expect(PageTiles.rects(width: 1532, height: 1024).count == 1)
        #expect(PageTiles.rects(width: 0, height: 100).isEmpty)
    }

    @Test("Reaching the end marks the chapter read once")
    func reachingEndMarksRead() async {
        let repository = FakeChapterRepository(chapters: [chapter(1)])
        await repository.script([pages(2)], for: chapter(1).id)
        let model = make(route(1, .manhwa), repository: repository)
        await model.load()

        model.onAction(.reachedEnd)
        model.onAction(.reachedEnd)
        await model.flushProgress()

        #expect(await repository.progressEnds() == [true])
        #expect(model.state.progress == 1)
        #expect(model.state.chapters.first?.isRead == true)
    }

    @Test("A partly read chapter reopens where it was left; a read one at the start")
    func restoresPosition() async {
        let partly = FakeChapterRepository(chapters: [chapter(1, position: 0.5)])
        await partly.script([pages(11)], for: chapter(1).id)
        let partlyModel = make(route(1, .manhwa), repository: partly)
        await partlyModel.load()
        #expect(partlyModel.state.initialIndex == 5)

        let read = FakeChapterRepository(chapters: [chapter(1, isRead: true, position: 1)])
        await read.script([pages(11)], for: chapter(1).id)
        let readModel = make(route(1, .manhwa), repository: read)
        await readModel.load()
        #expect(readModel.state.initialIndex == 0)
    }

    @Test("An unsaved series still reads, and the Reader says progress is not kept")
    func unsavedSeries() async {
        let repository = FakeChapterRepository(chapters: [chapter(1)], isSaved: false)
        await repository.script([pages(1)], for: chapter(1).id)
        let model = make(route(1, .manhwa), repository: repository)

        await model.load()
        await model.flushProgress()

        #expect(model.state.phase == .loaded)
        #expect(!model.state.isProgressStored)
    }

    @Test("Appearance changes apply at once and persist")
    func preferencesPersist() {
        let settings = InMemorySettingsStore()
        let model = make(
            route(1, .novel), repository: FakeChapterRepository(chapters: []), settings: settings)

        model.onAction(.setTheme(.sepia))
        model.onAction(.setTextScale(1.5))

        #expect(model.state.preferences.theme == .sepia)
        #expect(settings.readerPreferences.theme == .sepia)
        #expect(settings.readerPreferences.textScale == 1.5)
    }

    @Test("Tapping toggles the chrome; close emits the close effect")
    func chromeAndClose() async {
        let model = make(route(1, .novel), repository: FakeChapterRepository(chapters: []))
        #expect(model.state.controlsVisible)
        model.onAction(.toggleControls)
        #expect(!model.state.controlsVisible)

        var effects = model.effects.makeAsyncIterator()
        model.onAction(.close)
        #expect(await effects.next() == .close)
    }

    @Test("The download control queues the current chapter under its series' title")
    func downloadCurrentChapter() async throws {
        let repository = FakeChapterRepository(chapters: [chapter(1)])
        await repository.script([pages(1)], for: chapter(1).id)
        let downloads = FakeDownloadRepository()
        let model = make(route(1, .manhwa), repository: repository, downloads: downloads)
        await model.load()
        #expect(model.state.seriesTitle == "The Series")

        model.onAction(.download)
        try await waitUntil { await downloads.enqueued.count == 1 }

        let request = try #require(await downloads.enqueued.first)
        #expect(request.chapters == [chapter(1).id])
        #expect(request.seriesTitle == "The Series")
        #expect(request.contentType == .manhwa)
    }

    @Test("The download control reflects the current chapter's state")
    func downloadStateFollows() async throws {
        let repository = FakeChapterRepository(chapters: [chapter(1)])
        await repository.script([pages(1)], for: chapter(1).id)
        let downloads = FakeDownloadRepository()
        let model = make(route(1, .manhwa), repository: repository, downloads: downloads)
        await model.load()
        let observation = Task { await model.observeDownloads() }
        defer { observation.cancel() }

        await downloads.publish(
            DownloadQueueSnapshot(
                entries: [
                    DownloadEntry(
                        chapter: chapter(1).chapter, seriesTitle: "The Series",
                        contentType: .manhwa, state: .completed, enqueuedAt: .now)
                ],
                storageBytes: 1))

        try await waitUntil { model.state.currentDownloadState == .completed }
    }
}

extension ChapterContent {
    fileprivate var imageURLs: [URL] {
        if case .pages(let urls) = self { return urls }
        return []
    }
}

extension ReaderModelTests {
    @Test("Opening a chapter and backing out records the open, never the chapter")
    func openWithoutReadingWritesNoProgress() async throws {
        let repository = FakeChapterRepository(chapters: [chapter(1, position: 0.5), chapter(2)])
        await repository.script([pages(101)], for: chapter(1).id)
        await repository.script([pages(51)], for: chapter(2).id)
        let model = make(route(1, .manhwa), repository: repository)
        await model.load()

        model.onAction(.positionChanged(index: 52))  // 2% from where it opened
        model.onAction(.nextChapter)
        try await waitUntil { model.state.document == .pages(pages(51).imageURLs) }
        model.onAction(.close)
        await model.flushProgress()

        #expect(await repository.progressPositions().isEmpty)
        #expect(await repository.opens == 2)
        #expect(model.state.chapters.first?.readingPosition == 0.5)
    }

    @Test("Moving far enough from where a chapter opened counts as reading it")
    func movingFromOpenedPositionWrites() async {
        let repository = FakeChapterRepository(chapters: [chapter(1, position: 0.5)])
        await repository.script([pages(101)], for: chapter(1).id)
        let model = make(route(1, .manhwa), repository: repository)
        await model.load()

        model.onAction(.positionChanged(index: 40))  // 10% back from 50%
        model.onAction(.close)
        await model.flushProgress()

        #expect(await repository.progressPositions() == [0.4, 0.4])
    }
}
