import CoreSpotlight
import Foundation
import Testing

@testable import Readr

@Suite("Spotlight identifier and attributes")
struct SpotlightTests {
    private let id = SeriesID(
        sourceID: -1_234_567_890_123, url: URL(string: "https://example.test/series/a?c=1&d=2")!)

    @Test("Identifiers round-trip through (sourceID, url)")
    func identifierRoundTrips() {
        let identifier = SpotlightIdentifier.make(for: id)
        #expect(identifier.hasPrefix("series|"))
        #expect(SpotlightIdentifier.seriesID(from: identifier) == id)
    }

    @Test(
        "Anything Readr did not write is rejected",
        arguments: ["", "chapter|1|https://x.test", "series|abc|https://x.test", "series|1|nope"])
    func foreignIdentifiers(identifier: String) {
        #expect(SpotlightIdentifier.seriesID(from: identifier) == nil)
    }

    @Test("A blank-titled series is indexed under its placeholder, never an empty string")
    func blankTitleIndexesPlaceholder() {
        let series = Series(
            sourceID: 1, url: URL(string: "https://example.test/series/the-swordmaster")!,
            title: " ", contentType: .manhwa)
        let item = SpotlightAttributes.Item(series: series, sourceName: "AsuraScans")
        let attributes = SpotlightAttributes.attributeSet(for: item)

        #expect(item.title == "The Swordmaster")
        #expect(attributes.title == "The Swordmaster")
        #expect(attributes.displayName == "The Swordmaster")
    }

    @Test("Series-level metadata is carried: source, author, genres, synopsis, thumbnail")
    func carriesSeriesMetadata() {
        let series = Series(
            sourceID: 1, url: URL(string: "https://example.test/series/x")!, title: "X",
            synopsis: "A synopsis.", author: "Author", genres: ["Action", "Drama"],
            contentType: .novel)
        let thumbnail = URL(fileURLWithPath: "/tmp/thumb.img")
        let item = SpotlightAttributes.Item(
            series: series, sourceName: "Source", thumbnailURL: thumbnail)
        let searchable = SpotlightAttributes.searchableItem(for: item, domain: "d")

        #expect(searchable.uniqueIdentifier == SpotlightIdentifier.make(for: series.id))
        #expect(searchable.domainIdentifier == "d")
        let attributes = searchable.attributeSet
        #expect(attributes.contentDescription == "A synopsis.")
        #expect(attributes.keywords == ["Source", "Action", "Drama", "Author"])
        #expect(attributes.thumbnailURL == thumbnail)
    }
}
