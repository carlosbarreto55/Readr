import Foundation
import SwiftData

/// `LibraryRepository` backed by SwiftData.
///
/// A `@ModelActor`, so every access runs on the actor's own `ModelContext` off the
/// main actor (invariant 7). Entities never leave it: each method maps to domain
/// values before returning (invariant 12).
@ModelActor
actor SwiftDataLibraryRepository: LibraryRepository {

    func savedItems() throws -> [LibraryItem] {
        var descriptor = FetchDescriptor<SeriesEntity>()
        descriptor.sortBy = [SortDescriptor(\.dateAdded, order: .reverse)]
        return try modelContext.fetch(descriptor).compactMap(SeriesMapper.toLibraryItem)
    }

    func savedSeries() throws -> [Series] {
        try savedItems().map(\.series)
    }

    func series(_ id: SeriesID) throws -> Series? {
        try entity(for: id).flatMap(SeriesMapper.toDomain)
    }

    func isSaved(_ id: SeriesID) throws -> Bool {
        try entity(for: id) != nil
    }

    func save(_ series: Series) throws {
        if let existing = try entity(for: series.id) {
            // Already saved: refresh its metadata and leave the reader's own
            // state — dateAdded, lastReadAt, chapters — exactly as it was.
            SeriesMapper.apply(series, to: existing)
        } else {
            modelContext.insert(SeriesMapper.makeEntity(from: series))
        }
        try modelContext.save()
    }

    /// - Note: `library-browse-catalog` also requires removal to delete the
    ///   series' downloaded payloads. There is no download storage yet; that is
    ///   wired into this method when downloads are built.
    func remove(_ id: SeriesID) throws {
        guard let existing = try entity(for: id) else { return }
        // Chapters and their read state go with it, by the relationship's
        // cascade delete rule.
        modelContext.delete(existing)
        try modelContext.save()
    }

    /// - Note: unordered by contract. `existing.chapters` is a SwiftData
    ///   to-many relationship, which carries no ordering guarantee, so no order
    ///   is imposed here rather than one being implied.
    func chapters(for id: SeriesID) throws -> [Chapter] {
        guard let existing = try entity(for: id) else {
            throw LibraryRepositoryError.seriesNotSaved(id)
        }
        return existing.chapters.compactMap(ChapterMapper.toDomain)
    }

    func libraryChapters(for id: SeriesID) throws -> [LibraryChapter] {
        guard let existing = try entity(for: id) else {
            throw LibraryRepositoryError.seriesNotSaved(id)
        }
        return ChapterReadingOrder.sorted(
            existing.chapters.compactMap(ChapterMapper.toLibraryChapter))
    }

    func storeChapters(_ chapters: [Chapter], for id: SeriesID) throws {
        guard let existing = try entity(for: id) else {
            throw LibraryRepositoryError.seriesNotSaved(id)
        }
        try rejectForeign(chapters, for: id)

        var storedByKey: [String: ChapterEntity] = [:]
        for stored in existing.chapters {
            storedByKey[stored.key] = stored
        }

        // Additive: unlike `mergeChapterList`, a stored chapter absent from
        // `chapters` is left exactly as it was.
        for (index, chapter) in chapters.enumerated() {
            let key = EntityKey.identity(sourceID: chapter.sourceID, url: chapter.url)
            if let stored = storedByKey[key] {
                ChapterMapper.apply(chapter, to: stored)
                stored.sourceIndex = index
            } else {
                let entity = ChapterMapper.makeEntity(from: chapter)
                entity.sourceIndex = index
                entity.series = existing
                modelContext.insert(entity)
                storedByKey[key] = entity
            }
        }
        try modelContext.save()
    }

    func mergeChapterList(_ chapters: [Chapter], for id: SeriesID) throws {
        guard let existing = try entity(for: id) else {
            throw LibraryRepositoryError.seriesNotSaved(id)
        }
        // An empty refresh is a failed refresh. Merging it would mark every
        // stored chapter unlisted — the series would look emptied upstream on
        // the strength of one bad response.
        guard !chapters.isEmpty else {
            throw LibraryRepositoryError.emptyChapterList(id)
        }
        try rejectForeign(chapters, for: id)

        var storedByKey: [String: ChapterEntity] = [:]
        for stored in existing.chapters {
            storedByKey[stored.key] = stored
        }

        do {
            var listedKeys: Set<String> = []
            for (index, chapter) in chapters.enumerated() {
                let key = EntityKey.identity(sourceID: chapter.sourceID, url: chapter.url)
                // A source listing the same chapter twice keeps its first position.
                guard listedKeys.insert(key).inserted else { continue }

                if let stored = storedByKey[key] {
                    ChapterMapper.apply(chapter, to: stored)
                    stored.sourceIndex = index
                    stored.isListedUpstream = true
                } else {
                    let entity = ChapterMapper.makeEntity(from: chapter)
                    entity.sourceIndex = index
                    entity.series = existing
                    modelContext.insert(entity)
                }
            }

            // Absent upstream: marked, never deleted. The row carries read state
            // and, once downloads exist, names a stored payload.
            for (key, stored) in storedByKey where !listedKeys.contains(key) {
                stored.isListedUpstream = false
            }

            try modelContext.save()
        } catch {
            // Nothing partial survives a failed merge.
            modelContext.rollback()
            throw error
        }
    }

    func setRead(_ chapterIDs: [ChapterID], isRead: Bool, in series: SeriesID) throws {
        guard let existing = try entity(for: series) else {
            throw LibraryRepositoryError.seriesNotSaved(series)
        }
        let keys = Set(chapterIDs.map { EntityKey.identity(sourceID: $0.sourceID, url: $0.url) })
        for stored in existing.chapters where keys.contains(stored.key) {
            stored.isRead = isRead
            stored.readingPosition = isRead ? 1 : 0
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// Rejects foreign chapters before anything is written.
    ///
    /// Lookups during a write are scoped to one series, so a chapter whose
    /// identity is already stored under a *different* series would miss the
    /// lookup, take the insert branch, and collide with the unique key — which
    /// upserts rather than throwing, silently reparenting that row and the read
    /// state it carries.
    private func rejectForeign(_ chapters: [Chapter], for id: SeriesID) throws {
        for chapter in chapters {
            guard chapter.sourceID == id.sourceID, chapter.seriesURL == id.url else {
                throw LibraryRepositoryError.chapterNotInSeries(chapter: chapter.id, series: id)
            }
        }
    }

    private func entity(for id: SeriesID) throws -> SeriesEntity? {
        let key = EntityKey.identity(sourceID: id.sourceID, url: id.url)
        var descriptor = FetchDescriptor<SeriesEntity>(
            predicate: #Predicate { $0.key == key }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
