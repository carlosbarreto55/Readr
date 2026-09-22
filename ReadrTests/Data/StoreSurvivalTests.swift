import Foundation
import SwiftData
import Testing

@testable import Readr

/// Proves that data written to an on-disk store is still there after the store is
/// closed and reopened through `ReadrMigrationPlan`.
///
/// There is no migration to test yet — `SchemaV1` is the only version. This exists
/// now so that the first real migration extends a harness instead of inventing
/// one, and so the claim "reopening does not lose data" is checked from the first
/// release rather than assumed.
///
/// **Extending this for a migration**: write through the *previous* schema's
/// container, reopen through the plan, and assert the migrated values — the shape
/// below, with the write side pinned to the older version.
@Suite("Store survival")
struct StoreSurvivalTests {
    private let seriesURL = URL(string: "https://example.test/series/one")!
    private let chapterURL = URL(string: "https://example.test/series/one/ch/1")!

    private func makeContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
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

    @Test("The migration plan is wired and names SchemaV1 as its baseline")
    func planIsWired() {
        #expect(ReadrMigrationPlan.schemas.count == 1)
        #expect(ReadrMigrationPlan.stages.isEmpty)
        #expect(SchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(SchemaV1.models.count == 2)
    }
}
