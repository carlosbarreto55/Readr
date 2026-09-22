import Foundation
import Testing

@testable import Readr

/// A route carries every identifier its destination needs to load, so a
/// destination never reads ambient state to discover what it is showing.
@Suite("Routes")
struct RouteTests {
    private let sourceID: Int64 = 42
    private let seriesURL = URL(string: "https://example.test/series/one")!
    private let chapterURL = URL(string: "https://example.test/series/one/ch/1")!

    @Test("A series route carries the source identifier and the series URL")
    func seriesRouteCarriesIdentity() {
        guard
            case .series(let id) = LibraryRoute.series(SeriesID(sourceID: sourceID, url: seriesURL))
        else {
            Issue.record("Expected .series")
            return
        }
        #expect(id.sourceID == sourceID)
        #expect(id.url == seriesURL)
    }

    @Test("Routes naming the same series compare equal")
    func sameSubjectRoutesAreEqual() {
        let first = LibraryRoute.series(SeriesID(sourceID: sourceID, url: seriesURL))
        let second = LibraryRoute.series(SeriesID(sourceID: sourceID, url: seriesURL))
        #expect(first == second)
    }

    @Test("Routes naming different series do not compare equal")
    func differentSubjectRoutesDiffer() {
        let one = LibraryRoute.series(SeriesID(sourceID: sourceID, url: seriesURL))
        let other = LibraryRoute.series(SeriesID(sourceID: 43, url: seriesURL))
        #expect(one != other)
    }

    @Test("A chapter route carries everything the Reader needs")
    func readerRouteCarriesIdentity() {
        let route = ReaderRoute(
            sourceID: sourceID,
            seriesURL: seriesURL,
            chapterURL: chapterURL,
            contentType: .manhwa
        )
        #expect(route.sourceID == sourceID)
        #expect(route.seriesURL == seriesURL)
        #expect(route.chapterURL == chapterURL)
        #expect(route.contentType == .manhwa)
        #expect(route.id == ChapterID(sourceID: sourceID, url: chapterURL))
    }

    /// The Reader must be able to tell that a loaded payload disagrees with what
    /// the route promised, so the promised type is part of the route.
    @Test("Chapter routes differing only in content type are different routes")
    func contentTypeIsPartOfTheRoute() {
        let asNovel = ReaderRoute(
            sourceID: sourceID, seriesURL: seriesURL, chapterURL: chapterURL, contentType: .novel)
        let asManhwa = ReaderRoute(
            sourceID: sourceID, seriesURL: seriesURL, chapterURL: chapterURL, contentType: .manhwa)
        #expect(asNovel != asManhwa)
    }

    @Test("Every tab has a title and an icon")
    func tabsArePresentable() {
        #expect(AppTab.allCases.count == 4)
        for tab in AppTab.allCases {
            #expect(tab.title.isEmpty == false)
            #expect(tab.systemImage.isEmpty == false)
        }
    }
}
