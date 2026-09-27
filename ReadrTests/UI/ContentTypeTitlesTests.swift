import Foundation
import Testing

@testable import Readr

@Suite("Content type titles")
struct ContentTypeTitlesTests {

    @Test("Every content type has its own singular and plural name")
    func titles() {
        #expect(ContentType.allCases.map(\.title) == ["Novel", "Manhwa", "Manga", "Comic"])
        #expect(
            ContentType.allCases.map(\.pluralTitle) == ["Novels", "Manhwa", "Manga", "Comics"])
    }

    @Test("Browse names each source by what it offers")
    func browseTitles() {
        #expect(
            ContentType.allCases.map(\.browseTitle) == ["Web Novels", "Manhwa", "Manga", "HQs"])
    }

    @Test("Comics are read in issues; everything else in chapters")
    func units() {
        #expect(ContentType.comic.unitTitle == "Issue")
        #expect(ContentType.comic.pluralUnitTitle == "Issues")
        #expect(ContentType.manga.unitTitle == "Chapter")
        #expect(ContentType.novel.pluralUnitTitle == "Chapters")
    }

    @Test("A comic series header counts issues and names its type")
    func comicSeriesHeader() {
        let url = URL(string: "https://readcomicsonline.lol/comic/Absolute-Batman")!
        let chapters = (1...2).map {
            LibraryChapter(
                chapter: Chapter(
                    sourceID: 1, seriesURL: url, url: url.appending(path: "\($0)"),
                    name: "#\($0)"))
        }
        var state = SeriesState()
        state.series = Series(
            sourceID: 1, url: url, title: "Absolute Batman", status: .ongoing,
            contentType: .comic)
        state.sourceName = "ReadComicsOnline"
        state.chapters = chapters

        #expect(state.metadataLine == "Ongoing · Comic · ReadComicsOnline")
        #expect(state.chapterCountLabel == "2 Issues")
        state.chapters = [chapters[0]]
        #expect(state.chapterCountLabel == "1 Issue")
    }
}
