import Foundation
import SwiftData
import Testing

@testable import Readr

/// Proves that data written to an on-disk store is still there after the store is
/// closed and reopened through `ReadrMigrationPlan` — both at the current schema
/// and across every migration stage.
///
/// **Extending this for a migration**: write through the *previous* schema's
/// frozen models, reopen through the plan, and assert the migrated values — the
/// shape of `v1StoreMigratesToV2`.
@Suite("Store survival")
struct StoreSurvivalTests {
    private let seriesURL = URL(string: "https://example.test/series/one")!
    private let chapterURL = URL(string: "https://example.test/series/one/ch/1")!

    private func makeContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: ReadrMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: url)
        )
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "readr-survival-\(UUID().uuidString).store")
    }

    @Test("A library written to disk is intact after the store is reopened")
    func libraryOutlivesTheContainer() async throws {
        let storeURL = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let id = SeriesID(sourceID: 42, url: seriesURL)

        // Written through one container, which is then released.
        do {
            let repository = SwiftDataLibraryRepository(
                modelContainer: try makeContainer(at: storeURL))
            try await repository.save(
                Series(
                    sourceID: 42,
                    url: seriesURL,
                    title: "Survives",
                    genres: ["Fantasy"],
                    status: .ongoing,
                    contentType: .manhwa
                )
            )
            try await repository.storeChapters(
                [
                    Chapter(
                        sourceID: 42, seriesURL: seriesURL, url: chapterURL, name: "Ch. 1",
                        number: 1)
                ],
                for: id
            )
        }

        // Read back through a second container over the same file.
        let reopened = SwiftDataLibraryRepository(modelContainer: try makeContainer(at: storeURL))

        let restored = try await reopened.series(id)
        #expect(restored?.title == "Survives")
        #expect(restored?.genres == ["Fantasy"])
        #expect(restored?.status == .ongoing)
        #expect(restored?.contentType == .manhwa)

        // Still reachable by (sourceID, url), which is what every downloaded
        // payload path and every progress record is keyed against.
        #expect(restored?.id == id)
        #expect(try await reopened.chapters(for: id).map(\.name) == ["Ch. 1"])
    }

    @Test("Reopening an empty store yields an empty library, not a failure")
    func emptyStoreReopens() async throws {
        let storeURL = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL) }

        _ = try makeContainer(at: storeURL)
        let reopened = SwiftDataLibraryRepository(modelContainer: try makeContainer(at: storeURL))
        #expect(try await reopened.savedSeries().isEmpty)
    }

    @Test("The migration plan runs v1 → v2 as one lightweight stage")
    func planIsWired() {
        #expect(ReadrMigrationPlan.schemas.count == 2)
        #expect(ReadrMigrationPlan.stages.count == 1)
        #expect(SchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(SchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
        #expect(SchemaV1.models.count == 2)
        #expect(SchemaV2.models.count == 2)
    }

    @Test("A v1 store migrates to v2 with identity, metadata, and read state intact")
    func v1StoreMigratesToV2() async throws {
        let storeURL = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let id = SeriesID(sourceID: 42, url: seriesURL)
        let added = Date(timeIntervalSince1970: 1_000)
        let read = Date(timeIntervalSince1970: 2_000)

        try writeV1Store(at: storeURL, added: added, read: read)

        let migrated = SwiftDataLibraryRepository(modelContainer: try makeContainer(at: storeURL))

        let items = try await migrated.savedItems()
        #expect(items.count == 1)
        #expect(items.first?.id == id)
        #expect(items.first?.series.title == "Migrates")
        #expect(items.first?.series.genres == ["Action"])
        #expect(items.first?.series.status == .ongoing)
        #expect(items.first?.series.contentType == .manhwa)
        #expect(items.first?.dateAdded == added)
        #expect(items.first?.lastReadAt == read)

        let chapters = try await migrated.libraryChapters(for: id)
        #expect(chapters.count == 1)
        let chapter = try #require(chapters.first)
        #expect(chapter.id == ChapterID(sourceID: 42, url: chapterURL))
        #expect(chapter.chapter.number == 1)
        #expect(chapter.isRead)
        #expect(chapter.readingPosition == 1)
        #expect(chapter.lastReadAt == read)
        // The new attributes arrive at their documented defaults.
        #expect(chapter.sourceIndex == 0)
        #expect(chapter.isListedUpstream)

        // And the migrated store accepts the v2 merge.
        try await migrated.mergeChapterList(
            [
                Chapter(
                    sourceID: 42, seriesURL: seriesURL,
                    url: chapterURL.deletingLastPathComponent().appending(path: "2"),
                    name: "Ch. 2", number: 2)
            ],
            for: id)
        let merged = try await migrated.libraryChapters(for: id)
        #expect(merged.map(\.chapter.name) == ["Ch. 1", "Ch. 2"])
        #expect(merged.first?.isRead == true)
        #expect(merged.first?.isListedUpstream == false)
    }

    /// A store written exactly as v1 wrote it: the frozen models, no plan.
    private func writeV1Store(at storeURL: URL, added: Date, read: Date) throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, url: storeURL))
        let context = ModelContext(container)
        let series = SchemaV1.SeriesEntity(
            sourceID: 42, url: seriesURL.absoluteString, title: "Migrates",
            statusRaw: "ongoing", contentTypeRaw: "manhwa", dateAdded: added)
        series.genres = ["Action"]
        series.lastReadAt = read
        let chapter = SchemaV1.ChapterEntity(
            sourceID: 42, seriesURL: seriesURL.absoluteString,
            url: chapterURL.absoluteString, name: "Ch. 1", number: 1)
        chapter.isRead = true
        chapter.readingPosition = 1
        chapter.lastReadAt = read
        chapter.series = series
        context.insert(series)
        context.insert(chapter)
        try context.save()
    }
}
