import Foundation

/// `ChapterRepository` over the library and the catalog.
///
/// Names only domain contracts, so what the Reader is served — and from where —
/// is tested with fakes.
struct DefaultChapterRepository: ChapterRepository {

    let library: any LibraryRepository
    let catalog: any CatalogRepository

    func chapters(
        in series: SeriesID, contentType: ContentType
    ) async throws -> [LibraryChapter] {
        if let saved = try await library.series(series) {
            let stored = try await library.libraryChapters(for: series)
            if !stored.isEmpty {
                return stored
            }
            return ChapterReadingOrder.sorted(
                LibraryChapter.unsaved(try await catalog.chapters(for: saved, refresh: false)))
        }

        let known =
            await catalog.knownSeries(series)
            ?? Series(
                sourceID: series.sourceID, url: series.url, title: "", contentType: contentType)
        return ChapterReadingOrder.sorted(
            LibraryChapter.unsaved(try await catalog.chapters(for: known, refresh: false)))
    }

    func content(for chapter: Chapter, bypassingStored: Bool) async throws -> ChapterContent {
        try await catalog.chapterContent(for: chapter)
    }

    func recordProgress(
        _ chapter: ChapterID, in series: SeriesID, position: Double, reachedEnd: Bool
    ) async throws -> ProgressRecording {
        guard try await library.isSaved(series) else { return .notInLibrary }
        try await library.recordProgress(
            chapter, in: series, position: position, reachedEnd: reachedEnd, at: .now)
        return .stored
    }
}
