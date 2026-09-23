import Foundation
import Testing

@testable import Readr

/// Library pull-to-refresh and blank-title display.
@Suite("LibraryModel refresh and placeholders")
@MainActor
struct LibraryRefreshModelTests {
    private let source = SourceInfo(
        id: 1, name: "Novel Source", lang: "en", baseURL: URL(string: "https://novel.test")!,
        contentType: .novel)

    private func item(_ title: String, slug: String) -> LibraryItem {
        LibraryItem(
            series: Series(
                sourceID: 1, url: URL(string: "https://novel.test/series/\(slug)")!,
                title: title, contentType: .novel),
            dateAdded: Date(timeIntervalSince1970: 1_000))
    }

    private func makeModel(
        library: InMemoryLibraryRepository, refresher: any SeriesRepository
    ) -> LibraryModel {
        LibraryModel(
            library: library,
            catalog: ScriptedCatalogRepository(sources: [source]),
            settings: InMemorySettingsStore(),
            refresher: refresher)
    }

    @Test("Pull-to-refresh refreshes the library and shows a repaired title in place")
    func pullToRefreshRepairsBlankTitle() async {
        let blank = item("", slug: "the-long-road")
        let library = InMemoryLibraryRepository(items: [blank])
        let refresher = RecordingSeriesRepository {
            try? await library.save(
                Series(
                    sourceID: 1, url: blank.series.url, title: "Repaired Title",
                    contentType: .novel))
        }
        let model = makeModel(library: library, refresher: refresher)
        await model.load()
        #expect(model.state.items.map(\.series.displayTitle) == ["The Long Road"])

        await model.refreshLibrary()

        #expect(await refresher.refreshLibraryCalls == 1)
        #expect(model.state.phase == .populated)
        #expect(model.state.items.map(\.series.displayTitle) == ["Repaired Title"])
    }

    @Test("A blank-titled series shows, sorts by, and is removable under its placeholder")
    func blankTitleUsesPlaceholder() async {
        let blank = item("  ", slug: "middle-march")
        let library = InMemoryLibraryRepository(items: [
            item("Zebra", slug: "zebra"), blank, item("Apple", slug: "apple")
        ])
        let model = makeModel(library: library, refresher: RecordingSeriesRepository())
        await model.load()
        model.onAction(.selectSort(.title))

        #expect(
            model.state.items.map(\.series.displayTitle) == ["Apple", "Middle March", "Zebra"])

        await model.removeSeries(blank.id)
        #expect(model.state.items.map(\.series.displayTitle) == ["Apple", "Zebra"])
        #expect(await library.removeCalls == [blank.id])
    }
}
