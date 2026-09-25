import Foundation

/// Something that must follow library membership: storage to free when a series
/// is removed, an index to update when one is saved.
///
/// Notified only after the library write succeeded. Observers do not throw — a
/// failure to follow the library must never fail the library operation itself.
protocol LibraryChangeObserver: Sendable {
    func librarySaved(_ series: Series) async
    func libraryRemoved(_ id: SeriesID) async
}

/// A `LibraryRepository` that forwards every call and tells its observers about
/// saves and removals.
///
/// A decorator rather than hooks inside the SwiftData repository, so the store
/// stays about the store and each follower — downloads now, Spotlight in M9 — is
/// added at the composition root without the library knowing it exists.
struct ObservedLibraryRepository: LibraryRepository {
    let base: any LibraryRepository
    let observers: [any LibraryChangeObserver]

    func savedItems() async throws -> [LibraryItem] { try await base.savedItems() }
    func savedSeries() async throws -> [Series] { try await base.savedSeries() }
    func series(_ id: SeriesID) async throws -> Series? { try await base.series(id) }
    func isSaved(_ id: SeriesID) async throws -> Bool { try await base.isSaved(id) }

    func save(_ series: Series) async throws {
        try await base.save(series)
        for observer in observers {
            await observer.librarySaved(series)
        }
    }

    func remove(_ id: SeriesID) async throws {
        try await base.remove(id)
        for observer in observers {
            await observer.libraryRemoved(id)
        }
    }

    func chapters(for id: SeriesID) async throws -> [Chapter] {
        try await base.chapters(for: id)
    }

    func libraryChapters(for id: SeriesID) async throws -> [LibraryChapter] {
        try await base.libraryChapters(for: id)
    }

    func storeChapters(_ chapters: [Chapter], for id: SeriesID) async throws {
        try await base.storeChapters(chapters, for: id)
    }

    func mergeChapterList(_ chapters: [Chapter], for id: SeriesID) async throws {
        try await base.mergeChapterList(chapters, for: id)
    }

    func setRead(_ chapterIDs: [ChapterID], isRead: Bool, in series: SeriesID) async throws {
        try await base.setRead(chapterIDs, isRead: isRead, in: series)
    }

    func recordProgress(
        _ chapter: ChapterID, in series: SeriesID, position: Double, reachedEnd: Bool,
        at date: Date
    ) async throws {
        try await base.recordProgress(
            chapter, in: series, position: position, reachedEnd: reachedEnd, at: date)
    }

    func recordOpened(_ series: SeriesID, at date: Date) async throws {
        try await base.recordOpened(series, at: date)
    }
}

extension DefaultDownloadRepository: LibraryChangeObserver {
    func librarySaved(_ series: Series) async {}

    /// `library-browse-catalog`: removing a series deletes its downloaded
    /// payloads, and the space they used.
    func libraryRemoved(_ id: SeriesID) async {
        try? deleteAll(in: id)
    }
}
