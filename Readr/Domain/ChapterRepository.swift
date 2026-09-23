import Foundation

/// What the Reader needs: a series' chapters, a chapter's content, and a place to
/// record how far the reader got.
///
/// Presentation never learns whether content came from the source or, once
/// downloads exist, from disk — that decision is this repository's.
public protocol ChapterRepository: Sendable {

    /// The series' chapters in reading order. A saved series with stored chapters
    /// is answered from the library, with its reader state; anything else from
    /// the catalog, unread.
    ///
    /// - Parameters:
    ///   - series: The series whose chapters to list.
    ///   - contentType: The series' shape, for a series nothing has described yet.
    /// - Returns: The chapters, first chapter first.
    /// - Throws: Whatever the library or catalog threw.
    func chapters(
        in series: SeriesID, contentType: ContentType
    ) async throws -> [LibraryChapter]

    /// The chapter's content.
    ///
    /// - Parameters:
    ///   - chapter: The chapter to read.
    ///   - bypassingStored: `true` fetches from the source even when a stored
    ///     payload exists — for the Reader's one forced re-fetch when content
    ///     disagrees with the route's type.
    /// - Returns: The chapter's text or page images.
    /// - Throws: Whatever the source or storage threw.
    func content(for chapter: Chapter, bypassingStored: Bool) async throws -> ChapterContent

    /// Records how far through `chapter` the reader got.
    ///
    /// - Parameters:
    ///   - chapter: The chapter being read.
    ///   - series: The series it belongs to.
    ///   - position: 0 to 1.
    ///   - reachedEnd: Marks the chapter read. A chapter already read stays read.
    /// - Returns: Whether anything was stored. A series outside the library has no
    ///   record to store progress against.
    /// - Throws: Whatever the library threw while writing.
    @discardableResult
    func recordProgress(
        _ chapter: ChapterID, in series: SeriesID, position: Double, reachedEnd: Bool
    ) async throws -> ProgressRecording
}

/// Whether progress was stored.
public enum ProgressRecording: Sendable, Equatable {
    case stored
    /// The series is not in the library, so there is nothing to store against.
    case notInLibrary
}
