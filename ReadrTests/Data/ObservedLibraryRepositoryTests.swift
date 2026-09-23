import Foundation
import Testing

@testable import Readr

private actor RecordingObserver: LibraryChangeObserver {
    private(set) var saved: [SeriesID] = []
    private(set) var removed: [SeriesID] = []

    func librarySaved(_ series: Series) { saved.append(series.id) }
    func libraryRemoved(_ id: SeriesID) { removed.append(id) }
}

@Suite("ObservedLibraryRepository")
struct ObservedLibraryRepositoryTests {
    private let series = Series(
        sourceID: 1, url: URL(string: "https://example.test/s")!, title: "S", contentType: .novel)

    @Test("Observers hear about saves and removals after they succeed")
    func notifiesAfterSuccess() async throws {
        let observer = RecordingObserver()
        let repository = ObservedLibraryRepository(
            base: InMemoryLibraryRepository(), observers: [observer])

        try await repository.save(series)
        try await repository.remove(series.id)

        #expect(await observer.saved == [series.id])
        #expect(await observer.removed == [series.id])
    }

    @Test("A failed removal notifies no one")
    func failureNotifiesNoOne() async throws {
        let base = InMemoryLibraryRepository(items: [LibraryItem(series: series, dateAdded: .now)])
        await base.failing("remove")
        let observer = RecordingObserver()
        let repository = ObservedLibraryRepository(base: base, observers: [observer])

        await #expect(throws: FakeRepositoryError.failed) {
            try await repository.remove(series.id)
        }
        #expect(await observer.removed.isEmpty)
    }

    @Test("Removing a series from the library deletes its downloads")
    func removalDeletesDownloads() async throws {
        let container = try AppContainer.inMemory()
        let chapter = Chapter(
            sourceID: 1, seriesURL: series.url, url: series.url.appending(path: "1"), name: "1")
        try await container.library.save(series)
        // Enqueued with no source registered: it fails, but the entry exists.
        try await container.downloads.enqueue(
            [chapter], seriesTitle: "S", contentType: .novel)
        #expect(try await container.downloads.snapshot().entries.count == 1)

        try await container.library.remove(series.id)

        #expect(try await container.downloads.snapshot().entries.isEmpty)
    }
}
