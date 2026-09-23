import Foundation

@testable import Readr

enum FakeRepositoryError: Error, Equatable {
    case failed
}

/// A `LibraryRepository` with the real contract's semantics and no store.
///
/// For tests of the layers above the library — the series repository, screen
/// models — that need a library which merges, orders, and preserves read state
/// the way the real one does, without a `ModelContainer`. The real merge is
/// tested against SwiftData in `ChapterMergeTests`.
actor InMemoryLibraryRepository: LibraryRepository {

    private struct Stored {
        var item: LibraryItem
        var chapters: [ChapterID: LibraryChapter] = [:]
    }

    private var stored: [SeriesID: Stored] = [:]
    private var failures: Set<String> = []
    private(set) var mergeCalls: [SeriesID] = []
    private(set) var saveCalls: [Series] = []
    private(set) var removeCalls: [SeriesID] = []
    private(set) var progressCalls: [ChapterID] = []

    init(items: [LibraryItem] = []) {
        for item in items {
            stored[item.id] = Stored(item: item)
        }
    }

    /// Makes every later call to the named operation throw, until cleared.
    func failing(_ operation: String, _ shouldFail: Bool = true) {
        if shouldFail {
            failures.insert(operation)
        } else {
            failures.remove(operation)
        }
    }

    /// Seeds chapters with reader state, bypassing the merge.
    func seed(_ chapters: [LibraryChapter], for id: SeriesID) {
        for chapter in chapters {
            stored[id]?.chapters[chapter.id] = chapter
        }
    }

    func storedChapter(_ id: ChapterID, in series: SeriesID) -> LibraryChapter? {
        stored[series]?.chapters[id]
    }

    func savedItems() throws -> [LibraryItem] {
        try check("savedItems")
        return stored.values.map(\.item).sorted { $0.dateAdded > $1.dateAdded }
    }

    func savedSeries() throws -> [Series] {
        try savedItems().map(\.series)
    }

    func series(_ id: SeriesID) throws -> Series? {
        try check("series")
        return stored[id]?.item.series
    }

    func isSaved(_ id: SeriesID) throws -> Bool {
        try check("isSaved")
        return stored[id] != nil
    }

    func save(_ series: Series) throws {
        saveCalls.append(series)
        try check("save")
        if var existing = stored[series.id] {
            existing.item = LibraryItem(
                series: series, dateAdded: existing.item.dateAdded,
                lastReadAt: existing.item.lastReadAt)
            stored[series.id] = existing
        } else {
            stored[series.id] = Stored(item: LibraryItem(series: series, dateAdded: .now))
        }
    }

    func remove(_ id: SeriesID) throws {
        removeCalls.append(id)
        try check("remove")
        stored[id] = nil
    }

    func chapters(for id: SeriesID) throws -> [Chapter] {
        try libraryChapters(for: id).map(\.chapter)
    }

    func libraryChapters(for id: SeriesID) throws -> [LibraryChapter] {
        try check("libraryChapters")
        guard let entry = stored[id] else { throw LibraryRepositoryError.seriesNotSaved(id) }
        return ChapterReadingOrder.sorted(Array(entry.chapters.values))
    }

    func storeChapters(_ chapters: [Chapter], for id: SeriesID) throws {
        try check("storeChapters")
        guard stored[id] != nil else { throw LibraryRepositoryError.seriesNotSaved(id) }
        for (index, chapter) in chapters.enumerated() {
            let existing = stored[id]?.chapters[chapter.id]
            stored[id]?.chapters[chapter.id] = LibraryChapter(
                chapter: chapter,
                isRead: existing?.isRead ?? false,
                readingPosition: existing?.readingPosition ?? 0,
                lastReadAt: existing?.lastReadAt,
                sourceIndex: index,
                isListedUpstream: existing?.isListedUpstream ?? true)
        }
    }

    func mergeChapterList(_ chapters: [Chapter], for id: SeriesID) throws {
        mergeCalls.append(id)
        try check("mergeChapterList")
        guard var entry = stored[id] else { throw LibraryRepositoryError.seriesNotSaved(id) }
        guard !chapters.isEmpty else { throw LibraryRepositoryError.emptyChapterList(id) }
        if let foreign = chapters.first(where: {
            $0.sourceID != id.sourceID || $0.seriesURL != id.url
        }) {
            throw LibraryRepositoryError.chapterNotInSeries(chapter: foreign.id, series: id)
        }

        var listed: Set<ChapterID> = []
        for (index, chapter) in chapters.enumerated() where listed.insert(chapter.id).inserted {
            let existing = entry.chapters[chapter.id]
            entry.chapters[chapter.id] = LibraryChapter(
                chapter: chapter,
                isRead: existing?.isRead ?? false,
                readingPosition: existing?.readingPosition ?? 0,
                lastReadAt: existing?.lastReadAt,
                sourceIndex: index,
                isListedUpstream: true)
        }
        for (chapterID, chapter) in entry.chapters where !listed.contains(chapterID) {
            entry.chapters[chapterID] = LibraryChapter(
                chapter: chapter.chapter,
                isRead: chapter.isRead,
                readingPosition: chapter.readingPosition,
                lastReadAt: chapter.lastReadAt,
                sourceIndex: chapter.sourceIndex,
                isListedUpstream: false)
        }
        stored[id] = entry
    }

    func setRead(_ chapterIDs: [ChapterID], isRead: Bool, in series: SeriesID) throws {
        try check("setRead")
        guard stored[series] != nil else { throw LibraryRepositoryError.seriesNotSaved(series) }
        for chapterID in chapterIDs {
            guard let chapter = stored[series]?.chapters[chapterID] else { continue }
            stored[series]?.chapters[chapterID] = LibraryChapter(
                chapter: chapter.chapter,
                isRead: isRead,
                readingPosition: isRead ? 1 : 0,
                lastReadAt: chapter.lastReadAt,
                sourceIndex: chapter.sourceIndex,
                isListedUpstream: chapter.isListedUpstream)
        }
    }

    func recordProgress(
        _ chapter: ChapterID, in series: SeriesID, position: Double, reachedEnd: Bool, at date: Date
    ) throws {
        progressCalls.append(chapter)
        try check("recordProgress")
        guard var entry = stored[series] else {
            throw LibraryRepositoryError.seriesNotSaved(series)
        }
        guard let existing = entry.chapters[chapter] else { return }
        entry.chapters[chapter] = LibraryChapter(
            chapter: existing.chapter,
            isRead: existing.isRead || reachedEnd,
            readingPosition: position,
            lastReadAt: date,
            sourceIndex: existing.sourceIndex,
            isListedUpstream: existing.isListedUpstream)
        entry.item = LibraryItem(
            series: entry.item.series, dateAdded: entry.item.dateAdded, lastReadAt: date)
        stored[series] = entry
    }

    private func check(_ operation: String) throws {
        if failures.contains(operation) { throw FakeRepositoryError.failed }
    }
}

/// A `CatalogRepository` whose answers are set per series, recording every call.
actor ScriptedCatalogRepository: CatalogRepository {

    private let availableSources: [SourceInfo]
    private var detailResults: [SeriesID: Result<Series, FakeRepositoryError>] = [:]
    private var chapterResults: [SeriesID: Result<[Chapter], FakeRepositoryError>] = [:]
    private var known: [SeriesID: Series] = [:]
    private var contentResults: [ChapterID: [Result<ChapterContent, FakeRepositoryError>]] = [:]
    private(set) var contentCalls: [ChapterID] = []
    private(set) var detailCalls: [SeriesID] = []
    private(set) var chapterCalls: [SeriesID] = []
    private(set) var refreshFlags: [Bool] = []

    init(sources: [SourceInfo]) {
        availableSources = sources
    }

    func setDetails(_ result: Result<Series, FakeRepositoryError>, for id: SeriesID) {
        detailResults[id] = result
    }

    func setChapters(_ result: Result<[Chapter], FakeRepositoryError>, for id: SeriesID) {
        chapterResults[id] = result
    }

    /// Queues answers for a chapter's content, served in order; the last repeats.
    func setContent(_ results: [Result<ChapterContent, FakeRepositoryError>], for id: ChapterID) {
        contentResults[id] = results
    }

    func setKnown(_ series: Series) {
        known[series.id] = series
    }

    func sources() -> [SourceInfo] { availableSources }

    func popular(sourceID: Int64, page: Int, refresh: Bool) -> SeriesPage { .empty }
    func latest(sourceID: Int64, page: Int, refresh: Bool) -> SeriesPage { .empty }
    func search(
        sourceID: Int64, query: String, page: Int, filters: FilterList, refresh: Bool
    ) -> SeriesPage { .empty }

    func details(for series: Series, refresh: Bool) throws -> Series {
        detailCalls.append(series.id)
        refreshFlags.append(refresh)
        switch detailResults[series.id] {
        case .success(let details): return series.enriched(with: details)
        case .failure(let error): throw error
        case nil: return series
        }
    }

    func chapters(for series: Series, refresh: Bool) throws -> [Chapter] {
        chapterCalls.append(series.id)
        refreshFlags.append(refresh)
        switch chapterResults[series.id] {
        case .success(let chapters): return chapters
        case .failure(let error): throw error
        case nil: return []
        }
    }

    func chapterContent(for chapter: Chapter) throws -> ChapterContent {
        contentCalls.append(chapter.id)
        guard var queue = contentResults[chapter.id], let next = queue.first else {
            throw FakeRepositoryError.failed
        }
        if queue.count > 1 {
            queue.removeFirst()
            contentResults[chapter.id] = queue
        }
        return try next.get()
    }

    func knownSeries(_ id: SeriesID) -> Series? { known[id] }
    func supports(_ filter: Filter, sourceID: Int64) -> Bool { false }
    func clearCaches() {}
}
