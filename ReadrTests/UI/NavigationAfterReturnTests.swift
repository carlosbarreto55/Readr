import Foundation
import Testing

@testable import Readr

/// A screen whose effect consumer was cancelled — SwiftUI cancels a view's
/// `.task` when a route is pushed over it — must still navigate when it
/// reappears and subscribes again.
@Suite("Navigation after returning")
@MainActor
struct NavigationAfterReturnTests {
    private let source = SourceInfo(
        id: 1, name: "Source", lang: "en", baseURL: URL(string: "https://example.test")!,
        contentType: .novel)

    /// Subscribes the way a screen's `.task` does, then is cancelled the way
    /// SwiftUI cancels it on disappear.
    private func appearAndLeave<Effect: Sendable>(_ effects: AsyncStream<Effect>) async {
        let consumer = Task {
            for await _ in effects {}
        }
        consumer.cancel()
        await consumer.value
    }

    @Test("Browse opens a second source after returning from the first")
    func browseSourcesStayTappable() async {
        let model = BrowseModel(
            sourceID: nil, catalog: FakeBrowseCatalogRepository(sources: [source]),
            library: FakeBrowseLibraryRepository())

        var first = model.effects.makeAsyncIterator()
        model.onAction(.sourceSelected(1))
        #expect(await first.next() == .openSource(1))

        await appearAndLeave(model.effects)

        var returned = model.effects.makeAsyncIterator()
        model.onAction(.sourceSelected(2))
        #expect(await returned.next() == .openSource(2))
    }

    @Test("Library opens a series after returning from another")
    func libraryCardsStayTappable() async {
        let one = SeriesID(sourceID: 1, url: URL(string: "https://example.test/one")!)
        let two = SeriesID(sourceID: 1, url: URL(string: "https://example.test/two")!)
        let model = LibraryModel(
            library: InMemoryLibraryRepository(),
            catalog: ScriptedCatalogRepository(sources: [source]),
            settings: InMemorySettingsStore(), refresher: RecordingSeriesRepository())

        await appearAndLeave(model.effects)
        var returned = model.effects.makeAsyncIterator()
        model.onAction(.openSeries(one))
        model.onAction(.openSeries(two))

        #expect(await returned.next() == .openSeries(one))
        #expect(await returned.next() == .openSeries(two))
    }

    @Test("Downloads opens a series after returning")
    func downloadsHeadersStayTappable() async {
        let id = SeriesID(sourceID: 1, url: URL(string: "https://example.test/one")!)
        let model = DownloadsModel(downloads: FakeDownloadRepository())

        await appearAndLeave(model.effects)
        var returned = model.effects.makeAsyncIterator()
        model.onAction(.openSeries(id))

        #expect(await returned.next() == .openSeries(id))
    }
}
