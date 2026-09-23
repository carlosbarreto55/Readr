import Foundation

@testable import Readr

/// A `SeriesIndexing` that records what would have reached Spotlight, holding the
/// resulting index as a dictionary so tests can assert on its contents.
actor RecordingIndexer: SeriesIndexing {
    private(set) var items: [SeriesID: SpotlightAttributes.Item] = [:]
    private(set) var removeAllCalls = 0
    private(set) var indexCalls = 0

    func index(_ items: [SpotlightAttributes.Item]) {
        indexCalls += 1
        for item in items {
            self.items[item.id] = item
        }
    }

    func remove(_ ids: [SeriesID]) {
        for id in ids {
            items[id] = nil
        }
    }

    func removeAll() {
        removeAllCalls += 1
        items = [:]
    }
}

/// A `SystemSearchRepository` that records rebuilds and answers resolutions
/// from a table.
actor RecordingSystemSearchRepository: SystemSearchRepository {
    private var answers: [String: SystemSearchResolution] = [:]
    private(set) var rebuildCalls = 0

    func answer(_ resolution: SystemSearchResolution, for identifier: String) {
        answers[identifier] = resolution
    }

    func resolve(activityIdentifier: String) -> SystemSearchResolution {
        answers[activityIdentifier] ?? .unrecognized
    }

    func rebuildIndex() {
        rebuildCalls += 1
    }
}
