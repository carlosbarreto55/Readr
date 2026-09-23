import Foundation
import Testing

@testable import Readr

@Suite("Series display title")
struct SeriesDisplayTitleTests {

    private func series(_ title: String, url: String) -> Series {
        Series(sourceID: 1, url: URL(string: url)!, title: title, contentType: .novel)
    }

    @Test("A real title is shown trimmed")
    func realTitle() {
        let value = series("  The Swordmaster ", url: "https://example.test/series/x")
        #expect(value.displayTitle == "The Swordmaster")
        #expect(!value.hasBlankTitle)
    }

    @Test(
        "A blank title is replaced by a placeholder derived from the URL",
        arguments: [
            ("https://example.test/series/the-swordmaster-123", "The Swordmaster 123"),
            ("https://example.test/novel/long_road_home.html", "Long Road Home"),
            ("https://example.test/series/omniscient-reader/", "Omniscient Reader"),
            ("https://example.test/", "example.test")
        ])
    func placeholder(url: String, expected: String) {
        let value = series(" \n ", url: url)
        #expect(value.hasBlankTitle)
        #expect(value.displayTitle == expected)
    }

    @Test("The placeholder never changes identity")
    func identityUnchanged() {
        let blank = series("", url: "https://example.test/series/a")
        let titled = series("A", url: "https://example.test/series/a")
        #expect(blank == titled)
        #expect(blank.id == titled.id)
    }
}
