/// The library as the operating system's search sees it.
///
/// The index is a projection of the library, never a store of record
/// (`spotlight-indexable-series`): it is rebuilt from the library, and a result
/// is checked against the library before anything is opened.
public protocol SystemSearchRepository: Sendable {

    /// What a Spotlight result the reader opened refers to.
    ///
    /// A result for a series no longer saved has its stale index entry removed
    /// before `.noLongerSaved` is returned.
    func resolve(activityIdentifier: String) async -> SystemSearchResolution

    /// Replaces the index with one derived from the saved library.
    func rebuildIndex() async
}

public enum SystemSearchResolution: Sendable, Equatable {
    /// A saved series: open it.
    case series(SeriesID)
    /// Indexed once, since removed from the library. The entry is gone now.
    case noLongerSaved
    /// Not an identifier Readr writes.
    case unrecognized
}
