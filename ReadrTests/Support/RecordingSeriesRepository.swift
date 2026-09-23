import Foundation

@testable import Readr

/// A `SeriesRepository` that records library refreshes and runs an optional
/// action in place of one — standing in for what a real refresh would change.
actor RecordingSeriesRepository: SeriesRepository {
    private let onRefreshLibrary: @Sendable () async -> Void
    private(set) var refreshLibraryCalls = 0

    init(onRefreshLibrary: @escaping @Sendable () async -> Void = {}) {
        self.onRefreshLibrary = onRefreshLibrary
    }

    func stored(_ id: SeriesID) -> SeriesSnapshot? { nil }
    func seed(for id: SeriesID) throws -> Series { throw FakeRepositoryError.failed }
    func refresh(_ series: Series) throws -> SeriesSnapshot { throw FakeRepositoryError.failed }

    func refreshLibrary() async -> LibraryRefreshReport {
        refreshLibraryCalls += 1
        await onRefreshLibrary()
        return LibraryRefreshReport(refreshed: 1, failed: 0, repairedTitles: 0)
    }
}
