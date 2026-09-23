import Foundation

/// A stored chapter together with the reader's state for it.
///
/// Reader state — whether it was read, how far, and when — belongs to the
/// library, not to the source, so it lives beside `Chapter` rather than on it.
/// Identity remains the chapter's `(sourceID, url)`.
public struct LibraryChapter: Sendable, Identifiable, Hashable {
    public let chapter: Chapter
    public let isRead: Bool
    /// How far through the chapter the reader got, from 0 to 1.
    public let readingPosition: Double
    public let lastReadAt: Date?
    /// The position the source most recently listed this chapter at.
    public let sourceIndex: Int
    /// `false` once a refresh no longer finds this chapter at its source. The
    /// chapter and anything stored for it are kept regardless.
    public let isListedUpstream: Bool

    public init(
        chapter: Chapter,
        isRead: Bool = false,
        readingPosition: Double = 0,
        lastReadAt: Date? = nil,
        sourceIndex: Int = 0,
        isListedUpstream: Bool = true
    ) {
        self.chapter = chapter
        self.isRead = isRead
        self.readingPosition = readingPosition
        self.lastReadAt = lastReadAt
        self.sourceIndex = sourceIndex
        self.isListedUpstream = isListedUpstream
    }

    public var id: ChapterID { chapter.id }

    /// Whether the reader has started this chapter without finishing it.
    public var isInProgress: Bool { !isRead && readingPosition > 0 }

    public static func == (lhs: LibraryChapter, rhs: LibraryChapter) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension LibraryChapter {
    /// Remote chapters with no reader state, positioned as the source listed them.
    ///
    /// For a series that is not saved: there is no stored state to carry, so every
    /// chapter is unread at its listed position.
    public static func unsaved(_ chapters: [Chapter]) -> [LibraryChapter] {
        chapters.enumerated().map { index, chapter in
            LibraryChapter(chapter: chapter, sourceIndex: index)
        }
    }
}
