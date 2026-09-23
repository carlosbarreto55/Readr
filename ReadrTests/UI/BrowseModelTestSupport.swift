import Foundation

@testable import Readr

enum BrowseTestError: Error {
    case failed
}

enum CatalogOperation: Sendable, Hashable {
    case popular(page: Int)
    case latest(page: Int)
    case search(query: String, page: Int)
}

enum CatalogResult: Sendable {
    case success(SeriesPage)
    case failure
}

private struct CatalogResponse: Sendable {
    let result: CatalogResult
    let delay: Duration
}

actor FakeBrowseCatalogRepository: CatalogRepository {
    private let availableSources: [SourceInfo]
    private var responses: [CatalogOperation: [CatalogResponse]] = [:]
    private var recordedOperations: [CatalogOperation] = []

    init(sources: [SourceInfo]) {
        availableSources = sources
    }

    func enqueue(
        _ operation: CatalogOperation,
        result: CatalogResult,
        delay: Duration = .zero
    ) {
        responses[operation, default: []].append(
            CatalogResponse(result: result, delay: delay)
        )
    }

    func operations() -> [CatalogOperation] {
        recordedOperations
    }

    func sources() -> [SourceInfo] { availableSources }

    func popular(sourceID: Int64, page: Int, refresh: Bool) async throws -> SeriesPage {
        try await fetch(.popular(page: page))
    }

    func latest(sourceID: Int64, page: Int, refresh: Bool) async throws -> SeriesPage {
        try await fetch(.latest(page: page))
    }

    func search(
        sourceID: Int64,
        query: String,
        page: Int,
        filters: FilterList,
        refresh: Bool
    ) async throws -> SeriesPage {
        try await fetch(.search(query: query, page: page))
    }

    func details(for series: Series, refresh: Bool) -> Series { series }
    func chapters(for series: Series, refresh: Bool) -> [Chapter] { [] }
    func supports(_ filter: Filter, sourceID: Int64) -> Bool { false }
    func clearCaches() {}

    private func fetch(_ operation: CatalogOperation) async throws -> SeriesPage {
        recordedOperations.append(operation)
        let response: CatalogResponse
        if var queued = responses[operation], !queued.isEmpty {
            response = queued.removeFirst()
            responses[operation] = queued
        } else {
            response = CatalogResponse(result: .success(.empty), delay: .zero)
        }

        if response.delay > .zero {
            try await Task.sleep(for: response.delay)
        }

        switch response.result {
        case .success(let page):
            return page
        case .failure:
            throw BrowseTestError.failed
        }
    }
}

actor FakeBrowseLibraryRepository: LibraryRepository {
    private var items: [LibraryItem]
    private var failNextSave = false
    private var failNextRemoval = false
    private var savedItemsShouldFail = false
    private var savedItemsDelay: Duration = .zero
    private var savedItemsCallCount = 0
    private var savedSeriesCalls: [Series] = []
    private var removedIDCalls: [SeriesID] = []

    init(items: [LibraryItem] = []) {
        self.items = items
    }

    func makeNextSaveFail() {
        failNextSave = true
    }

    func makeNextRemovalFail() {
        failNextRemoval = true
    }

    func setSavedItemsShouldFail(_ shouldFail: Bool) {
        savedItemsShouldFail = shouldFail
    }

    func setSavedItemsDelay(_ delay: Duration) {
        savedItemsDelay = delay
    }

    func saveCalls() -> [Series] { savedSeriesCalls }
    func removeCalls() -> [SeriesID] { removedIDCalls }
    func savedItemsCalls() -> Int { savedItemsCallCount }

    func savedItems() async throws -> [LibraryItem] {
        savedItemsCallCount += 1
        let result = items
        let shouldFail = savedItemsShouldFail
        let delay = savedItemsDelay
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        if shouldFail { throw BrowseTestError.failed }
        return result
    }

    func savedSeries() -> [Series] { items.map(\.series) }

    func series(_ id: SeriesID) -> Series? {
        items.first(where: { $0.id == id })?.series
    }

    func isSaved(_ id: SeriesID) -> Bool {
        items.contains(where: { $0.id == id })
    }

    func save(_ series: Series) throws {
        savedSeriesCalls.append(series)
        if failNextSave {
            failNextSave = false
            throw BrowseTestError.failed
        }
        guard !items.contains(where: { $0.id == series.id }) else { return }
        items.append(LibraryItem(series: series, dateAdded: .now))
    }

    func remove(_ id: SeriesID) throws {
        removedIDCalls.append(id)
        if failNextRemoval {
            failNextRemoval = false
            throw BrowseTestError.failed
        }
        items.removeAll(where: { $0.id == id })
    }

    func chapters(for id: SeriesID) -> [Chapter] { [] }
    func storeChapters(_ chapters: [Chapter], for id: SeriesID) {}
}
