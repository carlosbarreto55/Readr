import Foundation

/// The Spotlight item identifier for a series: `series|<sourceID>|<url>`.
///
/// Derived from `(sourceID, url)` so a series has one item however often it is
/// re-indexed, and decodable back to that identity when a result is opened. The
/// one place the format is written or read.
enum SpotlightIdentifier {
    static let prefix = "series|"

    static func make(for id: SeriesID) -> String {
        "\(prefix)\(id.sourceID)|\(id.url.absoluteString)"
    }

    /// - Returns: `nil` for anything Readr did not write.
    static func seriesID(from identifier: String) -> SeriesID? {
        guard identifier.hasPrefix(prefix) else { return nil }
        let rest = identifier.dropFirst(prefix.count)
        guard let separator = rest.firstIndex(of: "|"),
            let sourceID = Int64(rest[..<separator]),
            let url = URL(string: String(rest[rest.index(after: separator)...])),
            url.scheme != nil
        else {
            return nil
        }
        return SeriesID(sourceID: sourceID, url: url)
    }
}
