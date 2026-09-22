/// FNV-1a, 64-bit, over the UTF-8 bytes of a string.
///
/// Exists because Swift's `Hasher` is seeded randomly per process and so cannot
/// be used for anything persisted: a value derived from it changes on every
/// launch. Nothing crashes when that happens, which is what makes it dangerous —
/// see `architecture.md` §4.1.
///
/// This function is deterministic across processes, devices, and installs. The
/// offset basis and prime are the published FNV-1a 64 constants and are part of
/// the persisted format, not tuning parameters.
public func stableHash64(_ string: String) -> UInt64 {
    let offsetBasis: UInt64 = 14_695_981_039_346_656_037
    let prime: UInt64 = 1_099_511_628_211

    var hash = offsetBasis
    for byte in string.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* prime
    }
    return hash
}
