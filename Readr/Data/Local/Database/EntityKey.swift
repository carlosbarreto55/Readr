import Foundation

/// Derives the two keys the persistence layer needs from `(sourceID, url)`.
///
/// Both are derived here and nowhere else. They are different on purpose:
///
/// - `identity` is the database's unique constraint. It carries the URL in full,
///   because a collision there would merge two series into one.
/// - `path` is a filesystem path component. It is hashed, because it has to be
///   short and safe on every filesystem; a collision is tolerable where a full
///   URL is not, and the store is the index from a path back to a chapter.
///
/// Both are part of the persisted format. `path` in particular names directories
/// that already hold downloaded files — changing its derivation strands them.
/// See `architecture.md` §6.3.
enum EntityKey {

    /// The unique key a `@Model` is stored under: `"<sourceID>|<url>"`.
    static func identity(sourceID: Int64, url: URL) -> String {
        "\(sourceID)|\(url.absoluteString)"
    }

    /// The unique key for a stored URL string, for reading back what the database
    /// already holds without rebuilding a `URL`.
    static func identity(sourceID: Int64, urlString: String) -> String {
        "\(sourceID)|\(urlString)"
    }

    /// The filesystem path component for a URL: 16 lowercase hex characters.
    static func path(for url: URL) -> String {
        String(format: "%016llx", stableHash64(url.absoluteString))
    }
}
