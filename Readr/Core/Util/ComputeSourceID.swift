/// Derives the stable identifier for a source.
///
/// `sourceID` is half of the `(sourceID, url)` key under which every series,
/// chapter, progress record, and downloaded file is stored, so it must produce the
/// same value for the same source on every launch, on every device, forever.
/// It is computed here and nowhere else, and never hand-picked.
///
/// FNV-1a 64 is chosen over a SHA-256 prefix because the property required is
/// determinism rather than collision resistance, and because a handful of
/// verifiable lines are worth more than a dependency for a value that can never
/// change.
///
/// - Note: `type` contributes `rawValue`, never the case name. `ContentType`'s raw
///   values are frozen for exactly this reason — interpolating the case itself
///   would compile, pass on the day it was written, and silently re-key the whole
///   library the first time somebody renamed a case.
///
/// - Important: `ReadrTests/Core/ComputeSourceIDTests.swift` asserts hardcoded
///   expected values. If it fails, the implementation regressed — correct the
///   implementation, never the expectation.
public func computeSourceID(name: String, lang: String, type: ContentType) -> Int64 {
    Int64(bitPattern: stableHash64("\(name)/\(lang)/\(type.rawValue)"))
}
