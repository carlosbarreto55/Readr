/// The reader's saved series and the chapter state belonging to them.
///
/// Domain values in and out. Nothing in this contract names a storage type — see
/// invariant 12.
public protocol LibraryRepository: Sendable {

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
    /// keyed by identity, not as a list, so a caller that needs an order imposes
    /// one. Whether an explicit stored index is required is the open question
    /// M6 answers when it first refreshes a chapter list against a live source.
    func chapters(for id: SeriesID) async throws -> [Chapter]

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
}

/// What a library operation can fail with.
public enum LibraryRepositoryError: Error, Equatable, Sendable {
    /// An operation named a series that is not in the library.
    case seriesNotSaved(SeriesID)

    /// A chapter was offered to a series it does not belong to. Identity is
    /// `(sourceID, url)` and a chapter carries its own `seriesURL`, so this is a
    /// caller bug rather than a condition the store can resolve.
    case chapterNotInSeries(chapter: ChapterID, series: SeriesID)
}
