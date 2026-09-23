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
    /// The first unread chapter after the last one read, so a reader who skipped
    /// ahead does not get sent back; the first chapter if nothing was read; `nil`
    /// only for an empty list. When everything is read, the last chapter.
    public static func continueTarget(in ordered: [LibraryChapter]) -> LibraryChapter? {
        if let inProgress = ordered.last(where: \.isInProgress) {
            return inProgress
        }
        guard let lastReadIndex = ordered.lastIndex(where: \.isRead) else {
            return ordered.first
        }
        let after = ordered.index(after: lastReadIndex)
        if let next = ordered[after...].first(where: { !$0.isRead }) {
            return next
        }
        return ordered.last
    }
}
