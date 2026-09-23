import Foundation
import Testing

@testable import Readr

@Suite("LibraryItem")
struct LibraryItemTests {
    private let url = URL(string: "https://example.test/series/one")!

    @Test("It exposes the series identity and reader-owned timestamps")
    func values() {
        let added = Date(timeIntervalSince1970: 1_000)
        let read = Date(timeIntervalSince1970: 2_000)
        let series = Series(
            sourceID: 42,
            url: url,
            title: "A Title",
            contentType: .novel
        )

        let item = LibraryItem(series: series, dateAdded: added, lastReadAt: read)

        #expect(item.id == SeriesID(sourceID: 42, url: url))
        #expect(item.series.title == "A Title")
        #expect(item.dateAdded == added)
        #expect(item.lastReadAt == read)
    }

    @Test("Identity ignores refreshed metadata and reader timestamps")
    func identity() {
        let before = LibraryItem(
            series: Series(sourceID: 42, url: url, title: "Before", contentType: .novel),
            dateAdded: Date(timeIntervalSince1970: 1_000)
        )
        let after = LibraryItem(
            series: Series(sourceID: 42, url: url, title: "After", contentType: .novel),
            dateAdded: Date(timeIntervalSince1970: 2_000),
            lastReadAt: Date(timeIntervalSince1970: 3_000)
        )

        #expect(before == after)
        #expect(Set([before, after]).count == 1)
    }
}
