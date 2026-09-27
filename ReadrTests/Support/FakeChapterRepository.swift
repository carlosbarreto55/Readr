import Foundation

@testable import Readr

struct ProgressWrite: Sendable {
    let position: Double
    let reachedEnd: Bool
}

/// Serves scripted content per chapter and records every call the Reader makes.
actor FakeChapterRepository: ChapterRepository {
    private let listed: [LibraryChapter]
    private var contents: [ChapterID: [ChapterContent]] = [:]
    private let isSaved: Bool
    private(set) var contentCalls: [(ChapterID, Bool)] = []
    private(set) var progress: [ProgressWrite] = []
    private(set) var opens = 0

    init(chapters: [LibraryChapter], isSaved: Bool = true) {
        listed = chapters
        self.isSaved = isSaved
    }

    /// Answers served in order for a chapter; the last one repeats.
    func script(_ answers: [ChapterContent], for id: ChapterID) {
        contents[id] = answers
    }

    func chapters(in series: SeriesID, contentType: ContentType) -> [LibraryChapter] { listed }

    func series(_ id: SeriesID, contentType: ContentType) -> Series {
        Series(sourceID: id.sourceID, url: id.url, title: "The Series", contentType: contentType)
    }

    func content(for chapter: Chapter, bypassingStored: Bool) throws -> ChapterContent {
        contentCalls.append((chapter.id, bypassingStored))
        guard var queue = contents[chapter.id], let next = queue.first else {
            throw FakeRepositoryError.failed
        }
        if queue.count > 1 {
            queue.removeFirst()
            contents[chapter.id] = queue
        }
        return next
    }

    func recordProgress(
        _ chapter: ChapterID, in series: SeriesID, position: Double, reachedEnd: Bool
    ) -> ProgressRecording {
        progress.append(ProgressWrite(position: position, reachedEnd: reachedEnd))
        return isSaved ? .stored : .notInLibrary
    }

    func recordOpened(in series: SeriesID) -> ProgressRecording {
        opens += 1
        return isSaved ? .stored : .notInLibrary
    }

    func bypassFlags() -> [Bool] { contentCalls.map(\.1) }
    func progressPositions() -> [Double] { progress.map(\.position) }
    func progressEnds() -> [Bool] { progress.map(\.reachedEnd) }
}
