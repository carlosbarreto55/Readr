/// The reader's saved series and the chapter state belonging to them.
///
/// Domain values in and out. Nothing in this contract names a storage type — see
/// invariant 12.
public protocol LibraryRepository: Sendable {

    /// Every saved item with its reader-owned metadata, most recently added
    /// first.
    func savedItems() async throws -> [LibraryItem]

    /// Every saved series, most recently added first.
    func savedSeries() async throws -> [Series]

    /// The saved series with this identity, or `nil` if it is not saved.
    func series(_ id: SeriesID) async throws -> Series?

    func isSaved(_ id: SeriesID) async throws -> Bool

    /// Saves a series, or updates the metadata of one already saved.
    ///
    /// Saving a series that is already saved MUST NOT duplicate it and MUST NOT
    /// reset the reader's own state — when it was added, when it was last read,
    /// or the progress recorded against its chapters.
    func save(_ series: Series) async throws

    /// Removes a series, its chapters, and their read state.
    func remove(_ id: SeriesID) async throws

    /// The stored chapters of a saved series.
    ///
    /// **Order is not part of this contract.** The store holds chapters as a set
    /// keyed by identity, not as a list. A caller that needs an order asks for
    /// `libraryChapters(for:)`, which is in reading order.
    func chapters(for id: SeriesID) async throws -> [Chapter]

    /// The stored chapters of a saved series with the reader's state for each, in
    /// reading order — see `ChapterReadingOrder`.
    func libraryChapters(for id: SeriesID) async throws -> [LibraryChapter]

    /// Stores chapters against a saved series.
    ///
    /// Chapters already stored have their remote metadata updated; their read
    /// state and reading position are preserved, because state follows
    /// `(sourceID, url)` rather than list position.
    ///
    /// - Throws: `chapterNotInSeries` if any chapter's `sourceID` or `seriesURL`
    ///   names a different series than `id`. Storing a foreign chapter would
    ///   either attach it to the wrong series or, if its identity is already
    ///   stored elsewhere, reparent that row and the read state it carries.
    func storeChapters(_ chapters: [Chapter], for id: SeriesID) async throws

    /// Merges a refreshed chapter list, in source order, into a saved series.
    ///
    /// This is the refresh merge `chapter-refresh-state-preservation` defines:
    /// - a stored chapter still listed has its metadata and source position
    ///   updated, and keeps its read state and position;
    /// - a new chapter is inserted unread;
    /// - a stored chapter the list omits is kept, with everything stored for it,
    ///   and marked as no longer listed upstream.
    ///
    /// The merge commits entirely or not at all.
    ///
    /// - Throws: `emptyChapterList` when `chapters` is empty — a source that
    ///   returns nothing has failed, and treating it as an emptied series would
    ///   mark every chapter unlisted. `chapterNotInSeries` for a foreign chapter.
    ///   `seriesNotSaved` when the series is not saved. Nothing is written when
    ///   anything throws.
    func mergeChapterList(_ chapters: [Chapter], for id: SeriesID) async throws

    /// Marks stored chapters read or unread.
    ///
    /// Marking read moves the position to the end; marking unread resets it to
    /// the start, so the chapter list and a reopened chapter agree. Chapters not
    /// stored against `series` are ignored.
    func setRead(_ chapterIDs: [ChapterID], isRead: Bool, in series: SeriesID) async throws
}

/// What a library operation can fail with.
public enum LibraryRepositoryError: Error, Equatable, Sendable {
    /// An operation named a series that is not in the library.
    case seriesNotSaved(SeriesID)

    /// A chapter was offered to a series it does not belong to. Identity is
    /// `(sourceID, url)` and a chapter carries its own `seriesURL`, so this is a
    /// caller bug rather than a condition the store can resolve.
    case chapterNotInSeries(chapter: ChapterID, series: SeriesID)

    /// A refresh returned no chapters. Treated as a failed refresh rather than as
    /// a series whose every chapter vanished.
    case emptyChapterList(SeriesID)
}
