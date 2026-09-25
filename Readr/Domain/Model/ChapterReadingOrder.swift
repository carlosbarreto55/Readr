import Foundation

/// Orders a series' chapters first-chapter-first.
///
/// Sources disagree about direction — one shipped plugin lists oldest-first,
/// the other newest-first — and the store holds chapters as a set, so order is
/// imposed here rather than inherited from wherever the chapters came from.
///
/// 1. When every chapter has a number, ascending number, ties broken by the
///    position the source listed them at.
/// 2. Otherwise the source's own order, reversed when its first and last
///    numbered chapters show that it lists newest-first.
///
/// A chapter no longer listed upstream keeps its last known source position, so
/// it stays where the reader last saw it.
public enum ChapterReadingOrder {

    public static func sorted(_ chapters: [LibraryChapter]) -> [LibraryChapter] {
        if chapters.allSatisfy({ $0.chapter.number != nil }) {
            return chapters.sorted { lhs, rhs in
                let left = lhs.chapter.number ?? 0
                let right = rhs.chapter.number ?? 0
                if left != right { return left < right }
                return lhs.sourceIndex < rhs.sourceIndex
            }
        }

        let bySource = chapters.sorted { lhs, rhs in
            if lhs.sourceIndex != rhs.sourceIndex { return lhs.sourceIndex < rhs.sourceIndex }
            return lhs.chapter.url.absoluteString < rhs.chapter.url.absoluteString
        }
        return listsNewestFirst(bySource) ? bySource.reversed() : bySource
    }

    /// Whether a list in source order runs from the highest number to the lowest.
    private static func listsNewestFirst(_ bySource: [LibraryChapter]) -> Bool {
        let numbers = bySource.compactMap(\.chapter.number)
        guard let first = numbers.first, let last = numbers.last else { return false }
        return first > last
    }

    /// Where a reader continuing this series should start.
    ///
    /// Anchored on the chapter read most recently — read or partly read, with a
    /// last-read time — so a chapter left unfinished long ago does not outrank
    /// the ones read since (`unified-reader-screen`). A partly read anchor is
    /// the target; a read one reopens at its start, so the target is the first
    /// unread chapter after it, or the last chapter when none is.
    ///
    /// With no timestamped anchor — chapters only marked read from the list —
    /// the first unread chapter after the last one read, so a reader who skipped
    /// ahead does not get sent back; the first chapter if nothing was read. `nil`
    /// only for an empty list.
    public static func continueTarget(in ordered: [LibraryChapter]) -> LibraryChapter? {
        if let anchorIndex = mostRecentlyReadIndex(in: ordered) {
            let anchor = ordered[anchorIndex]
            return anchor.isRead ? firstUnread(after: anchorIndex, in: ordered) : anchor
        }
        guard let lastReadIndex = ordered.lastIndex(where: \.isRead) else {
            return ordered.first
        }
        return firstUnread(after: lastReadIndex, in: ordered)
    }

    /// The engaged chapter with the latest last-read time; the later chapter on
    /// a tie. An unread chapter at its start was only opened, never read.
    private static func mostRecentlyReadIndex(in ordered: [LibraryChapter]) -> Int? {
        var best: (index: Int, date: Date)?
        for (index, chapter) in ordered.enumerated() {
            guard let date = chapter.lastReadAt, chapter.isRead || chapter.isInProgress
            else { continue }
            if let current = best, date < current.date { continue }
            best = (index, date)
        }
        return best?.index
    }

    private static func firstUnread(
        after index: Int, in ordered: [LibraryChapter]
    ) -> LibraryChapter? {
        ordered[(index + 1)...].first(where: { !$0.isRead }) ?? ordered.last
    }
}
