import Foundation
import SwiftData
import Testing

@testable import Readr

/// `chapter-refresh-state-preservation`, against the real store.
@Suite("Chapter list merge")
struct ChapterMergeTests {
    private let seriesURL = URL(string: "https://example.test/series/one")!
    private var id: SeriesID { SeriesID(sourceID: 42, url: seriesURL) }

    private func makeRepository() throws -> SwiftDataLibraryRepository {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: ReadrMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return SwiftDataLibraryRepository(modelContainer: container)
    }

    private func savedRepository() async throws -> SwiftDataLibraryRepository {
        let repository = try makeRepository()
        try await repository.save(
            Series(sourceID: 42, url: seriesURL, title: "Series", contentType: .novel))
        return repository
    }

    private func chapter(_ slug: String, name: String? = nil, number: Double? = nil) -> Chapter {
        Chapter(
            sourceID: 42, seriesURL: seriesURL, url: seriesURL.appending(path: slug),
            name: name ?? slug, number: number)
    }

    @Test("A refreshed chapter keeps read state and position and takes new metadata")
    func preservesStateUpdatesMetadata() async throws {
        let repository = try await savedRepository()
        try await repository.mergeChapterList([chapter("c1", number: 1)], for: id)
        try await repository.setRead([chapter("c1").id], isRead: true, in: id)

        try await repository.mergeChapterList(
            [chapter("c1", name: "Chapter 1: Renamed", number: 1)], for: id)

        let stored = try #require(try await repository.libraryChapters(for: id).first)
        #expect(stored.chapter.name == "Chapter 1: Renamed")
        #expect(stored.isRead)
        #expect(stored.readingPosition == 1)
        #expect(stored.isListedUpstream)
    }

    @Test("New chapters arrive unread at their source position")
    func newChaptersUnread() async throws {
        let repository = try await savedRepository()
        try await repository.mergeChapterList([chapter("c1", number: 1)], for: id)
        try await repository.setRead([chapter("c1").id], isRead: true, in: id)

        try await repository.mergeChapterList(
            [chapter("c2", number: 2), chapter("c1", number: 1)], for: id)

        let stored = try await repository.libraryChapters(for: id)
        #expect(stored.map(\.chapter.name) == ["c1", "c2"])
        #expect(stored.map(\.isRead) == [true, false])
        #expect(stored.map(\.sourceIndex) == [1, 0])
    }

    @Test("State follows identity when the source renumbers and reorders")
    func stateFollowsIdentity() async throws {
        let repository = try await savedRepository()
        try await repository.mergeChapterList(
            [chapter("a", number: 1), chapter("b", number: 2)], for: id)
        try await repository.setRead([chapter("a").id], isRead: true, in: id)

        // `a` is now listed second and renumbered to 2; `b` became 1.
        try await repository.mergeChapterList(
            [chapter("b", number: 1), chapter("a", number: 2)], for: id)

        let stored = try await repository.libraryChapters(for: id)
        #expect(stored.map(\.chapter.name) == ["b", "a"])
        #expect(stored.first { $0.chapter.name == "a" }?.isRead == true)
        #expect(stored.first { $0.chapter.name == "b" }?.isRead == false)
    }

    @Test("A chapter absent from a refresh is retained and marked unlisted")
    func absentChapterRetained() async throws {
        let repository = try await savedRepository()
        try await repository.mergeChapterList([chapter("c1"), chapter("c2")], for: id)
        try await repository.setRead([chapter("c2").id], isRead: true, in: id)

        try await repository.mergeChapterList([chapter("c1")], for: id)

        let stored = try await repository.libraryChapters(for: id)
        #expect(stored.count == 2)
        let gone = try #require(stored.first { $0.chapter.name == "c2" })
        #expect(!gone.isListedUpstream)
        #expect(gone.isRead)
        #expect(stored.first { $0.chapter.name == "c1" }?.isListedUpstream == true)

        // Listed again: marked listed again, state intact.
        try await repository.mergeChapterList([chapter("c1"), chapter("c2")], for: id)
        let relisted = try await repository.libraryChapters(for: id)
        #expect(relisted.allSatisfy { $0.isListedUpstream })
        #expect(relisted.first { $0.chapter.name == "c2" }?.isRead == true)
    }

    @Test("An empty refresh throws and leaves stored chapters untouched")
    func emptyRefreshFails() async throws {
        let repository = try await savedRepository()
        try await repository.mergeChapterList([chapter("c1"), chapter("c2")], for: id)
        let before = try await repository.libraryChapters(for: id)

        await #expect(throws: LibraryRepositoryError.emptyChapterList(id)) {
            try await repository.mergeChapterList([], for: id)
        }

        let after = try await repository.libraryChapters(for: id)
        #expect(after.map(\.id) == before.map(\.id))
        #expect(after.allSatisfy { $0.isListedUpstream })
    }

    @Test("A merge rejected partway writes nothing")
    func rejectedMergeWritesNothing() async throws {
        let repository = try await savedRepository()
        try await repository.mergeChapterList([chapter("c1", name: "Original")], for: id)

        let foreign = Chapter(
            sourceID: 42, seriesURL: URL(string: "https://example.test/series/other")!,
            url: URL(string: "https://example.test/series/other/x")!, name: "Foreign")
        await #expect(
            throws: LibraryRepositoryError.chapterNotInSeries(chapter: foreign.id, series: id)
        ) {
            try await repository.mergeChapterList(
                [chapter("c1", name: "Renamed"), chapter("c9"), foreign], for: id)
        }

        let stored = try await repository.libraryChapters(for: id)
        #expect(stored.map(\.chapter.name) == ["Original"])
        #expect(stored.allSatisfy { $0.isListedUpstream })
    }

    @Test("Merging into an unsaved series throws")
    func unsavedThrows() async throws {
        let repository = try makeRepository()
        await #expect(throws: LibraryRepositoryError.seriesNotSaved(id)) {
            try await repository.mergeChapterList([chapter("c1")], for: id)
        }
    }

    @Test("A duplicate listing keeps its first position")
    func duplicateKeepsFirst() async throws {
        let repository = try await savedRepository()
        try await repository.mergeChapterList(
            [chapter("c1"), chapter("c2"), chapter("c1")], for: id)
        let stored = try await repository.libraryChapters(for: id)
        #expect(stored.map(\.chapter.name) == ["c1", "c2"])
        #expect(stored.map(\.sourceIndex) == [0, 1])
    }

    @Test("Stored chapters read back newest-first sources in reading order")
    func readingOrder() async throws {
        let repository = try await savedRepository()
        try await repository.mergeChapterList(
            [chapter("c3", number: 3), chapter("c2", number: 2), chapter("c1", number: 1)],
            for: id)
        #expect(
            try await repository.libraryChapters(for: id).map(\.chapter.name)
                == ["c1", "c2", "c3"])
    }

    @Test("Marking unread resets position; marking read completes it")
    func setReadMovesPosition() async throws {
        let repository = try await savedRepository()
        try await repository.mergeChapterList([chapter("c1")], for: id)

        try await repository.setRead([chapter("c1").id], isRead: true, in: id)
        #expect(try await repository.libraryChapters(for: id).first?.readingPosition == 1)

        try await repository.setRead([chapter("c1").id], isRead: false, in: id)
        let stored = try #require(try await repository.libraryChapters(for: id).first)
        #expect(!stored.isRead)
        #expect(stored.readingPosition == 0)
    }
}
