import Foundation
import SwiftData
import Testing

@testable import Readr

@Suite("Reading progress")
struct ReadingProgressTests {
    private let seriesURL = URL(string: "https://example.test/series/one")!
    private var id: SeriesID { SeriesID(sourceID: 42, url: seriesURL) }
    private var chapter: Chapter {
        Chapter(
            sourceID: 42, seriesURL: seriesURL, url: seriesURL.appending(path: "c1"), name: "c1")
    }

    private func savedRepository() async throws -> SwiftDataLibraryRepository {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let container = try ModelContainer(
            for: schema, migrationPlan: ReadrMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let repository = SwiftDataLibraryRepository(modelContainer: container)
        try await repository.save(
            Series(sourceID: 42, url: seriesURL, title: "One", contentType: .novel))
        try await repository.mergeChapterList([chapter], for: id)
        return repository
    }

    @Test("Position is stored and stamps the chapter and series as read now")
    func storesPosition() async throws {
        let repository = try await savedRepository()
        let now = Date(timeIntervalSince1970: 5_000)

        try await repository.recordProgress(
            chapter.id, in: id, position: 0.4, reachedEnd: false, at: now)

        let stored = try #require(try await repository.libraryChapters(for: id).first)
        #expect(stored.readingPosition == 0.4)
        #expect(!stored.isRead)
        #expect(stored.lastReadAt == now)
        #expect(try await repository.savedItems().first?.lastReadAt == now)
    }

    @Test("Reaching the end marks read, and re-reading never marks unread")
    func reachedEndMarksRead() async throws {
        let repository = try await savedRepository()
        try await repository.recordProgress(
            chapter.id, in: id, position: 1, reachedEnd: true, at: .now)
        try await repository.recordProgress(
            chapter.id, in: id, position: 0.2, reachedEnd: false, at: .now)

        let stored = try #require(try await repository.libraryChapters(for: id).first)
        #expect(stored.isRead)
        #expect(stored.readingPosition == 0.2)
    }

    @Test("Out-of-range positions are clamped")
    func clamps() async throws {
        let repository = try await savedRepository()
        try await repository.recordProgress(
            chapter.id, in: id, position: 7, reachedEnd: false, at: .now)
        #expect(try await repository.libraryChapters(for: id).first?.readingPosition == 1)
    }

    @Test("An unsaved series throws and nothing is created")
    func unsavedThrows() async throws {
        let repository = try await savedRepository()
        let other = SeriesID(sourceID: 42, url: URL(string: "https://example.test/other")!)
        await #expect(throws: LibraryRepositoryError.seriesNotSaved(other)) {
            try await repository.recordProgress(
                chapter.id, in: other, position: 0.5, reachedEnd: true, at: .now)
        }
        #expect(try await repository.savedItems().count == 1)
    }
}
