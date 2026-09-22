import Foundation
import Testing

@testable import Readr

/// Series and chapter identity is `(sourceID, url)` — never title, never list
/// position. A source that retitles or renumbers must not move stored state
/// between records.
@Suite("Domain identity")
struct IdentityTests {
    private let url = URL(string: "https://example.test/series/one")!
    private let other = URL(string: "https://example.test/series/two")!

    private func series(sourceID: Int64, url: URL, title: String) -> Series {
        Series(sourceID: sourceID, url: url, title: title, contentType: .novel)
    }

    @Test("Metadata does not affect series identity")
    func seriesIdentityIgnoresMetadata() {
        let before = series(sourceID: 1, url: url, title: "Original Title")
        let after = series(sourceID: 1, url: url, title: "Retitled After Refresh")
        #expect(before == after)
        #expect(before.id == after.id)
    }

    @Test("A differing sourceID is a different series")
    func seriesIdentityIncludesSourceID() {
        #expect(
            series(sourceID: 1, url: url, title: "T") != series(sourceID: 2, url: url, title: "T"))
    }

    @Test("A differing URL is a different series")
    func seriesIdentityIncludesURL() {
        #expect(
            series(sourceID: 1, url: url, title: "T") != series(sourceID: 1, url: other, title: "T")
        )
    }

    @Test("Chapter identity follows (sourceID, url), not chapter number")
    func chapterIdentityIgnoresNumber() {
        let renumbered = Chapter(sourceID: 1, seriesURL: url, url: other, name: "Ch. 1", number: 1)
        let sameChapter = Chapter(
            sourceID: 1, seriesURL: url, url: other, name: "Ch. 01", number: 2)
        #expect(renumbered == sameChapter)
    }

    @Test("Identity survives a round trip through a set")
    func identityIsUsableAsAKey() {
        let set: Set<Series> = [
            series(sourceID: 1, url: url, title: "First"),
            series(sourceID: 1, url: url, title: "Same series, new title"),
            series(sourceID: 1, url: other, title: "Different series")
        ]
        #expect(set.count == 2)
    }
}
