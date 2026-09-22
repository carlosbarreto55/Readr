import Foundation
import SwiftData

/// `LibraryRepository` backed by SwiftData.
///
/// A `@ModelActor`, so every access runs on the actor's own `ModelContext` off the
/// main actor (invariant 7). Entities never leave it: each method maps to domain
/// values before returning (invariant 12).
@ModelActor
actor SwiftDataLibraryRepository: LibraryRepository {

    func savedSeries() throws -> [Series] {
        var descriptor = FetchDescriptor<SeriesEntity>()
        descriptor.sortBy = [SortDescriptor(\.dateAdded, order: .reverse)]
        return try modelContext.fetch(descriptor).compactMap(SeriesMapper.toDomain)
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

    func storeChapters(_ chapters: [Chapter], for id: SeriesID) throws {
        guard let existing = try entity(for: id) else {
            throw LibraryRepositoryError.seriesNotSaved(id)
        }

        // Reject foreign chapters before writing anything. `storedByKey` below is
        // scoped to this series, so a chapter whose identity is already stored
        // under a *different* series would miss the lookup, take the insert
        // branch, and collide with the unique key — which upserts rather than
        // throwing, silently reparenting that row and the read state it carries.
        for chapter in chapters {
            guard chapter.sourceID == id.sourceID, chapter.seriesURL == id.url else {
                throw LibraryRepositoryError.chapterNotInSeries(chapter: chapter.id, series: id)
            }
        }

        var storedByKey: [String: ChapterEntity] = [:]
        for stored in existing.chapters {
            storedByKey[stored.key] = stored
        }

        for chapter in chapters {
            let key = EntityKey.identity(sourceID: chapter.sourceID, url: chapter.url)
            if let stored = storedByKey[key] {
                ChapterMapper.apply(chapter, to: stored)
            } else {
                let entity = ChapterMapper.makeEntity(from: chapter)
                entity.series = existing
                modelContext.insert(entity)
            }
        }
        try modelContext.save()
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
