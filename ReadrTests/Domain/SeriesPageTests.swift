import Foundation
import Testing

@testable import Readr

@Suite("SeriesPage")
struct SeriesPageTests {

    private func series(_ path: String) -> Series {
        Series(
            sourceID: 1,
            url: URL(string: "https://example.test/\(path)")!,
            title: path,
            contentType: .novel
        )
    }

    /// A reachable catalog page that parses but holds nothing is not an error.
    /// `source-contract` requires it to come back as an empty page, not a throw.
    @Test("An empty page is representable and is not a failure")
    func emptyIsRepresentable() {
        #expect(SeriesPage.empty.entries.isEmpty)
        #expect(SeriesPage.empty.hasMore == false)
    }

    @Test("A page carries its entries in source order")
    func entriesKeepOrder() {
        let entries = [series("a"), series("b"), series("c")]
        #expect(SeriesPage(entries: entries, hasMore: true).entries == entries)
    }

    @Test("hasMore is independent of whether the page has entries")
    func hasMoreIsIndependent() {
        #expect(SeriesPage(entries: [], hasMore: true).hasMore)
        #expect(SeriesPage(entries: [series("a")], hasMore: false).hasMore == false)
    }
}
