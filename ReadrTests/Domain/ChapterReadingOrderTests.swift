import Foundation
import Testing

@testable import Readr

@Suite("Chapter reading order")
struct ChapterReadingOrderTests {
    private let seriesURL = URL(string: "https://example.test/series")!

    private func chapter(
        _ slug: String,
        number: Double?,
        index: Int,
        isRead: Bool = false,
        position: Double = 0,
        listed: Bool = true
    ) -> LibraryChapter {
        LibraryChapter(
            chapter: Chapter(
                sourceID: 1, seriesURL: seriesURL, url: seriesURL.appending(path: slug),
                name: slug, number: number),
            isRead: isRead,
            readingPosition: position,
            sourceIndex: index,
            isListedUpstream: listed)
    }

    @Test("A newest-first numbered list reads in ascending order")
    func descendingNumbersAscend() {
        let listed = [
            chapter("c3", number: 3, index: 0),
            chapter("c2", number: 2, index: 1),
            chapter("c1", number: 1, index: 2)
        ]
        #expect(ChapterReadingOrder.sorted(listed).map(\.chapter.name) == ["c1", "c2", "c3"])
    }

    @Test("Fractional and tied numbers order by number, then source position")
    func fractionalAndTies() {
        let listed = [
            chapter("c2-b", number: 2, index: 0),
            chapter("c1.5", number: 1.5, index: 1),
            chapter("c2-a", number: 2, index: 2)
        ]
        #expect(
            ChapterReadingOrder.sorted(listed).map(\.chapter.name) == ["c1.5", "c2-b", "c2-a"])
    }

    @Test("Unnumbered chapters keep the source's order")
    func unnumberedKeepSourceOrder() {
        let listed = [
            chapter("prologue", number: nil, index: 0),
            chapter("arrival", number: nil, index: 1),
            chapter("finale", number: nil, index: 2)
        ]
        #expect(
            ChapterReadingOrder.sorted(listed.reversed()).map(\.chapter.name)
                == ["prologue", "arrival", "finale"])
    }

    @Test("A partly numbered newest-first list is reversed")
    func partlyNumberedNewestFirst() {
        let listed = [
            chapter("c10", number: 10, index: 0),
            chapter("special", number: nil, index: 1),
            chapter("c1", number: 1, index: 2)
        ]
        #expect(
            ChapterReadingOrder.sorted(listed).map(\.chapter.name) == ["c1", "special", "c10"])
    }

    @Test("An unlisted chapter keeps its last known position")
    func unlistedKeepsPosition() {
        let listed = [
            chapter("a", number: nil, index: 0),
            chapter("gone", number: nil, index: 1, listed: false),
            chapter("c", number: nil, index: 2)
        ]
        #expect(ChapterReadingOrder.sorted(listed).map(\.chapter.name) == ["a", "gone", "c"])
    }

    @Test("Continue targets the first unread chapter after the last one read")
    func continueAfterLastRead() {
        let ordered = [
            chapter("c1", number: 1, index: 0, isRead: true, position: 1),
            chapter("c2", number: 2, index: 1),
            chapter("c3", number: 3, index: 2, isRead: true, position: 1),
            chapter("c4", number: 4, index: 3)
        ]
        #expect(ChapterReadingOrder.continueTarget(in: ordered)?.chapter.name == "c4")
    }

    @Test("Continue prefers a chapter in progress, and starts at the first when unread")
    func continueInProgressOrFirst() {
        let inProgress = [
            chapter("c1", number: 1, index: 0, isRead: true, position: 1),
            chapter("c2", number: 2, index: 1, position: 0.4),
            chapter("c3", number: 3, index: 2)
        ]
        #expect(ChapterReadingOrder.continueTarget(in: inProgress)?.chapter.name == "c2")

        let unread = [chapter("c1", number: 1, index: 0), chapter("c2", number: 2, index: 1)]
        #expect(ChapterReadingOrder.continueTarget(in: unread)?.chapter.name == "c1")
        #expect(ChapterReadingOrder.continueTarget(in: []) == nil)
    }

    @Test("Continue lands on the last chapter when everything is read")
    func continueAllRead() {
        let ordered = [
            chapter("c1", number: 1, index: 0, isRead: true, position: 1),
            chapter("c2", number: 2, index: 1, isRead: true, position: 1)
        ]
        #expect(ChapterReadingOrder.continueTarget(in: ordered)?.chapter.name == "c2")
    }
}
