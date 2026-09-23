import Foundation

/// How in-app Library search matches a query against a saved series.
///
/// Case- and diacritic-insensitive (`library-search-via-spotlight`): "naruto"
/// finds "Naruto", "pokemon" finds "Pokémon". Pure and synchronous, so search is
/// identical offline and never waits on the network or the Spotlight index.
public enum LibrarySearch {

    /// Whether `title` contains `query`, ignoring case, diacritics, and the
    /// query's surrounding whitespace. An empty query matches everything.
    public static func matches(_ query: String, title: String) -> Bool {
        let needle = normalize(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return true }
        return normalize(title).contains(needle)
    }

    /// Whether a query would filter anything at all.
    public static func isActive(_ query: String) -> Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func normalize(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX"))
    }
}
