import Testing

@testable import Readr

@Suite("ContentType and SeriesStatus raw values")
struct ContentTypeTests {

    /// `computeSourceID` hashes `ContentType.rawValue`, so these strings are
    /// part of the persisted format. Changing one re-keys every stored series,
    /// chapter, and downloaded file.
    @Test("ContentType raw values are frozen")
    func contentTypeRawValues() {
        #expect(ContentType.novel.rawValue == "novel")
        #expect(ContentType.manhwa.rawValue == "manhwa")
        #expect(ContentType.manga.rawValue == "manga")
        #expect(ContentType.comic.rawValue == "comic")
        #expect(ContentType.allCases.count == 4)
    }

    @Test("SeriesStatus has a landing place for unrecognized input")
    func seriesStatusUnknown() {
        #expect(SeriesStatus(rawValue: "somethingTheSiteMadeUp") == nil)
        #expect(SeriesStatus.unknown.rawValue == "unknown")
    }
}
