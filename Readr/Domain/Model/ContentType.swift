/// What shape of content a source publishes.
///
/// The raw values are **frozen**. `computeSourceID(name:lang:type:)` hashes
/// `rawValue`, and `sourceID` is half of the `(sourceID, url)` key under which
/// every series, chapter, progress record, and downloaded file is stored. Changing
/// a raw value re-keys the entire library; renaming a *case* is safe precisely
/// because the raw value is written out here rather than derived from the name.
///
/// See `architecture.md` §4.1.
public enum ContentType: String, Sendable, Hashable, CaseIterable, Codable {
    // swiftlint:disable redundant_string_enum_value
    // The raw values are written out deliberately. Letting them default to the
    // case names would make a rename silently re-key every stored series,
    // chapter, and downloaded file — the failure invariant 11 exists to prevent.
    case novel = "novel"
    case manhwa = "manhwa"
    case manga = "manga"
    case comic = "comic"
    // swiftlint:enable redundant_string_enum_value
}
