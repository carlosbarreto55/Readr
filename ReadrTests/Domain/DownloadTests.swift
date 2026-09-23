import Foundation
import Testing

@testable import Readr

@Suite("Download values")
struct DownloadTests {
    private let seriesURL = URL(string: "https://example.test/series")!

    private func entry(_ number: Int, _ state: DownloadState) -> DownloadEntry {
        DownloadEntry(
            chapter: Chapter(
                sourceID: 1, seriesURL: seriesURL, url: seriesURL.appending(path: "\(number)"),
                name: "\(number)"),
            seriesTitle: "S", contentType: .novel, state: state, enqueuedAt: .now)
    }

    @Test("Known totals are fractions; unknown totals are indeterminate, not zero")
    func progress() {
        #expect(DownloadProgress(completed: 3, total: 4).fraction == 0.75)
        #expect(DownloadProgress(completed: 0, total: 4).fraction == 0)
        #expect(DownloadProgress.indeterminate.fraction == nil)
        #expect(DownloadProgress(completed: 5, total: 0).fraction == nil)
        #expect(DownloadProgress(completed: 9, total: 4).fraction == 1)
    }

    @Test("A snapshot separates the queue from stored chapters")
    func snapshotPartitions() {
        let snapshot = DownloadQueueSnapshot(
            entries: [
                entry(1, .completed),
                entry(2, .downloading(.indeterminate)),
                entry(3, .pending),
                entry(4, .failed(message: "x", isRetryable: true))
            ],
            storageBytes: 10)

        #expect(snapshot.completed.map(\.chapter.name) == ["1"])
        #expect(snapshot.queue.map(\.chapter.name) == ["2", "3", "4"])
        #expect(snapshot.state(of: entry(3, .pending).id) == .pending)
        #expect(snapshot.states.count == 4)
    }

    @Test("Only pending and downloading count as queued")
    func queued() {
        #expect(DownloadState.pending.isQueued)
        #expect(DownloadState.downloading(.indeterminate).isQueued)
        #expect(!DownloadState.completed.isQueued)
        #expect(!DownloadState.failed(message: "", isRetryable: true).isQueued)
    }
}
