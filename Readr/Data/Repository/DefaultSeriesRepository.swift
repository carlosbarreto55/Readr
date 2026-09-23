import Foundation

/// `SeriesRepository` over the library and the catalog.
///
/// It names only the two domain contracts, never a source or the store, so the
/// orchestration — which of the two to read, which to write, and in what order —
/// is tested with fakes and no network.
///
/// An actor so the library refresh cannot run twice at once: pull-to-refresh and
/// app activation can both ask for one, and two concurrent walks would fetch
/// every series twice and race each other's merges.
actor DefaultSeriesRepository: SeriesRepository {

    private let library: any LibraryRepository
    private let catalog: any CatalogRepository
    private var libraryRefresh: Task<LibraryRefreshReport, Never>?

    init(library: any LibraryRepository, catalog: any CatalogRepository) {
        self.library = library
        self.catalog = catalog
    }

    func stored(_ id: SeriesID) async throws -> SeriesSnapshot? {
        guard let series = try await library.series(id) else { return nil }
        let chapters = try await library.libraryChapters(for: id)
        return SeriesSnapshot(series: series, chapters: chapters, isSaved: true)
    }

    func seed(for id: SeriesID) async throws -> Series {
        if let saved = try await library.series(id) {
            return saved
        }
        if let listed = await catalog.knownSeries(id) {
            return listed
        }
        guard let source = await catalog.sources().first(where: { $0.id == id.sourceID }) else {
            throw CatalogRepositoryError.unknownSource(id.sourceID)
        }
        // Identity and shape only. The title is blank on purpose: it renders as
        // the URL-derived placeholder until details arrive, rather than as a
        // guess that looks like real metadata.
        return Series(
            sourceID: id.sourceID, url: id.url, title: "", contentType: source.contentType)
    }

    func refresh(_ series: Series) async throws -> SeriesSnapshot {
        let details = try await catalog.details(for: series, refresh: true)
        let chapters = try await catalog.chapters(for: details, refresh: true)

        guard try await library.isSaved(series.id) else {
            return SeriesSnapshot(
                series: details,
                chapters: ChapterReadingOrder.sorted(LibraryChapter.unsaved(chapters)),
                isSaved: false)
        }

        // Details are saved only when they carry a title: a parse that lost it
        // must not overwrite a good stored title with a blank one.
        if !details.hasBlankTitle {
            try await library.save(details)
        }
        try await library.mergeChapterList(chapters, for: series.id)
        return try await stored(series.id)
            ?? SeriesSnapshot(
                series: details,
                chapters: ChapterReadingOrder.sorted(LibraryChapter.unsaved(chapters)),
                isSaved: false)
    }

    func refreshLibrary() async -> LibraryRefreshReport {
        if let libraryRefresh {
            return await libraryRefresh.value
        }
        let task = Task { await walkLibrary() }
        libraryRefresh = task
        let report = await task.value
        libraryRefresh = nil
        return report
    }

    private func walkLibrary() async -> LibraryRefreshReport {
        guard let saved = try? await library.savedSeries() else {
            return LibraryRefreshReport(refreshed: 0, failed: 0, repairedTitles: 0)
        }

        var refreshed = 0
        var failed = 0
        var repaired = 0

        for series in saved {
            if Task.isCancelled { break }
            do {
                var current = series
                if series.hasBlankTitle {
                    let details = try await catalog.details(for: series, refresh: true)
                    // A fetch that still yields no title leaves the series as it
                    // was — saved, blank, displayed by its placeholder — and it is
                    // tried again next refresh.
                    if !details.hasBlankTitle {
                        try await library.save(details)
                        current = details
                        repaired += 1
                    }
                }
                let chapters = try await catalog.chapters(for: current, refresh: true)
                try await library.mergeChapterList(chapters, for: series.id)
                refreshed += 1
            } catch {
                failed += 1
            }
        }
        return LibraryRefreshReport(refreshed: refreshed, failed: failed, repairedTitles: repaired)
    }
}
