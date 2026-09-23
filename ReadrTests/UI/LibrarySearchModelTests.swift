import Foundation
import Testing

@testable import Readr

/// In-app Library search (`library-search-via-spotlight`).
@Suite("LibraryModel search")
@MainActor
struct LibrarySearchModelTests {
    private let novels = SourceInfo(
        id: 1, name: "Novel Source", lang: "en", baseURL: URL(string: "https://novel.test")!,
        contentType: .novel)

    private func item(_ title: String, slug: String, type: ContentType = .novel) -> LibraryItem {
        LibraryItem(
            series: Series(
                sourceID: 1, url: URL(string: "https://novel.test/series/\(slug)")!,
                title: title, contentType: type),
            dateAdded: Date(timeIntervalSince1970: 1_000))
    }

    /// The catalog here answers only source metadata; any fetch is recorded, which
    /// is how "no network request" is asserted.
    private func makeModel(_ items: [LibraryItem]) -> (LibraryModel, ScriptedCatalogRepository) {
        let catalog = ScriptedCatalogRepository(sources: [novels])
        let model = LibraryModel(
            library: InMemoryLibraryRepository(items: items), catalog: catalog,
            settings: InMemorySettingsStore(), refresher: RecordingSeriesRepository())
        return (model, catalog)
    }

    @Test("A query matches saved titles regardless of case and diacritics, offline")
    func matchesLocally() async {
        let (model, catalog) = makeModel([
            item("Pokémon Adventures", slug: "pokemon"),
            item("Solo Leveling", slug: "solo"),
            item("The Legendary Mechanic", slug: "mechanic")
        ])
        await model.load()

        model.onAction(.searchTextChanged("POKEMON"))
        #expect(model.state.items.map(\.series.title) == ["Pokémon Adventures"])

        model.onAction(.searchTextChanged("le"))
        #expect(
            Set(model.state.items.map(\.series.title))
                == ["Solo Leveling", "The Legendary Mechanic"])

        #expect(await catalog.detailCalls.isEmpty)
        #expect(await catalog.chapterCalls.isEmpty)
        #expect(await catalog.contentCalls.isEmpty)
    }

    @Test("No match is its own state, distinct from an empty library and from filters")
    func distinctEmptyStates() async {
        let (empty, _) = makeModel([])
        await empty.load()
        empty.onAction(.searchTextChanged("anything"))
        #expect(empty.state.phase == .empty)

        let (filtered, _) = makeModel([item("Solo Leveling", slug: "solo")])
        await filtered.load()
        filtered.onAction(.selectContentFilter(.manhwa))
        filtered.onAction(.searchTextChanged("solo"))
        #expect(filtered.state.phase == .filteredEmpty)

        let (searched, _) = makeModel([item("Solo Leveling", slug: "solo")])
        await searched.load()
        searched.onAction(.searchTextChanged("  dragon "))
        #expect(searched.state.phase == .searchEmpty(query: "dragon"))

        searched.onAction(.searchTextChanged(""))
        #expect(searched.state.phase == .populated)
    }

    @Test("A blank-titled series is found by its placeholder")
    func blankTitleIsSearchable() async {
        let (model, _) = makeModel([item("", slug: "the-swordmaster")])
        await model.load()
        model.onAction(.searchTextChanged("swordmaster"))
        #expect(model.state.items.count == 1)
    }
}
