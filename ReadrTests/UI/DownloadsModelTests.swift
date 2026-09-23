import Foundation
import Testing

@testable import Readr

@Suite("DownloadsModel")
@MainActor
struct DownloadsModelTests {
    private let oneURL = URL(string: "https://example.test/series/one")!
    private let twoURL = URL(string: "https://example.test/series/two")!

    private func entry(
        _ seriesURL: URL, _ number: Int, _ state: DownloadState, title: String, bytes: Int64 = 0
    ) -> DownloadEntry {
        DownloadEntry(
            chapter: Chapter(
                sourceID: 1, seriesURL: seriesURL, url: seriesURL.appending(path: "\(number)"),
                name: "Chapter \(number)", number: Double(number)),
            seriesTitle: title, contentType: .novel, state: state, enqueuedAt: .now,
            byteCount: bytes)
    }

    @Test("A snapshot becomes the queue plus stored chapters grouped by series")
    func grouping() {
        let model = DownloadsModel(downloads: FakeDownloadRepository())
        model.apply(
            DownloadQueueSnapshot(
                entries: [
                    entry(twoURL, 2, .completed, title: "Zeta", bytes: 5),
                    entry(oneURL, 3, .pending, title: "Alpha"),
                    entry(twoURL, 1, .completed, title: "Zeta", bytes: 7),
                    entry(oneURL, 1, .completed, title: "Alpha", bytes: 1)
                ],
                storageBytes: 13))

        #expect(model.state.isLoaded)
        #expect(model.state.queue.map(\.chapter.name) == ["Chapter 3"])
        #expect(model.state.groups.map(\.title) == ["Alpha", "Zeta"])
        #expect(model.state.groups[1].entries.map(\.chapter.name) == ["Chapter 1", "Chapter 2"])
        #expect(model.state.groups[1].byteCount == 12)
        #expect(model.state.storageBytes == 13)
    }

    @Test("A blank series title is grouped under its URL-derived placeholder")
    func blankTitle() {
        let model = DownloadsModel(downloads: FakeDownloadRepository())
        model.apply(
            DownloadQueueSnapshot(
                entries: [entry(oneURL, 1, .completed, title: "")], storageBytes: 1))
        #expect(model.state.groups.first?.title == "One")
    }

    @Test("Observing follows pushed snapshots without polling")
    func observes() async throws {
        let downloads = FakeDownloadRepository()
        let model = DownloadsModel(downloads: downloads)
        let observation = Task { await model.observe() }
        defer { observation.cancel() }

        try await waitUntil { model.state.isLoaded }
        #expect(model.state.isEmpty)

        await downloads.publish(
            DownloadQueueSnapshot(
                entries: [entry(oneURL, 1, .downloading(.indeterminate), title: "Alpha")],
                storageBytes: 0))
        try await waitUntil { model.state.queue.count == 1 }
    }

    @Test("Row actions reach the repository")
    func actions() async throws {
        let downloads = FakeDownloadRepository()
        let model = DownloadsModel(downloads: downloads)
        let id = ChapterID(sourceID: 1, url: oneURL.appending(path: "1"))

        model.onAction(.retry(id))
        model.onAction(.cancel(id))
        model.onAction(.delete([id]))
        model.onAction(.deleteSeries(SeriesID(sourceID: 1, url: oneURL)))

        try await waitUntil { await downloads.deletedSeries.count == 1 }
        #expect(await downloads.retried == [id])
        #expect(await downloads.cancelled == [id])
        #expect(await downloads.deleted == [id])
    }

    @Test("Delete All asks first")
    func deleteAllConfirms() async throws {
        let downloads = FakeDownloadRepository()
        let model = DownloadsModel(downloads: downloads)

        model.onAction(.requestDeleteAll)
        #expect(model.state.isDeleteAllConfirmationPresented)
        model.onAction(.cancelDeleteAll)
        #expect(await downloads.deleteAllCalls == 0)

        model.onAction(.requestDeleteAll)
        model.onAction(.confirmDeleteAll)
        try await waitUntil { await downloads.deleteAllCalls == 1 }
    }

    @Test("A series header opens the series")
    func openSeries() async {
        let model = DownloadsModel(downloads: FakeDownloadRepository())
        var effects = model.effects.makeAsyncIterator()
        let id = SeriesID(sourceID: 1, url: oneURL)
        model.onAction(.openSeries(id))
        #expect(await effects.next() == .openSeries(id))
    }
}
