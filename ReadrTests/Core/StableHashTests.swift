import Testing

@testable import Readr

/// `stableHash64` is the reason anything persisted can be keyed at all. These
/// expectations are the published FNV-1a 64 test vectors plus the values this app
/// depends on; like the `computeSourceID` guard rail, they are never updated to
/// match changed output.
@Suite("stableHash64")
struct StableHashTests {

    @Test("Published FNV-1a 64 vectors")
    func knownVectors() {
        #expect(stableHash64("") == 14_695_981_039_346_656_037)
        #expect(stableHash64("a") == 12_638_187_200_555_641_996)
        #expect(stableHash64("foobar") == 9_625_390_261_332_436_968)
    }

    @Test("Hashing is deterministic within a process")
    func deterministic() {
        #expect(stableHash64("Readr") == stableHash64("Readr"))
    }

    @Test("Distinct inputs produce distinct hashes")
    func distinctInputs() {
        #expect(stableHash64("Readr") != stableHash64("readr"))
        #expect(stableHash64("ab") != stableHash64("ba"))
    }

    @Test("Multi-byte UTF-8 is hashed over all of its bytes")
    func utf8Bytes() {
        // "é" is two UTF-8 bytes; folding only the first would collide with "e".
        #expect(stableHash64("é") == 775_207_407_765_167_617)
        #expect(stableHash64("é") != stableHash64("e"))
        #expect(stableHash64("日本語") == 17_194_429_697_725_099_911)
    }
}
