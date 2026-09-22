import Testing

@testable import Readr

/// Guard rail for `computeSourceID`.
///
/// These expectations are **hardcoded on purpose**. `sourceID` is half of the
/// `(sourceID, url)` key under which every series, chapter, progress record, and
/// downloaded file is stored, so a change to the hash silently orphans the entire
/// library — nothing crashes, the library simply appears empty.
///
/// If a case here fails, the implementation regressed. Fix `computeSourceID`.
/// Never update the expectation to match new output. See `architecture.md` §4.1
/// and the `source-contract` capability.
@Suite("computeSourceID")
struct ComputeSourceIDTests {

    @Test("Known inputs produce their recorded identifiers")
    func knownValues() {
        #expect(
            computeSourceID(name: "Readr Test Source", lang: "en", type: .novel)
                == 3_356_894_637_208_931_763
        )
        #expect(
            computeSourceID(name: "Readr Test Source", lang: "en", type: .manhwa)
                == 6_577_290_571_411_179_067
        )
        #expect(
            computeSourceID(name: "Readr Test Source", lang: "pt-BR", type: .novel)
                == -97_034_467_889_323_295
        )
    }

    @Test("Empty components still hash, and negative results are representable")
    func edgeInputs() {
        // Proves the UInt64 -> Int64 conversion is by bit pattern: a hash above
        // Int64.max must land as a negative identifier rather than trapping.
        #expect(computeSourceID(name: "", lang: "", type: .novel) == 7_709_082_297_949_997_491)
        #expect(computeSourceID(name: "Readr Test Source", lang: "pt-BR", type: .novel) < 0)
    }

    @Test("The same input always produces the same identifier")
    func stability() {
        let first = computeSourceID(name: "Readr Test Source", lang: "en", type: .novel)
        let second = computeSourceID(name: "Readr Test Source", lang: "en", type: .novel)
        #expect(first == second)
    }

    @Test("Each component changes the identifier")
    func everyComponentContributes() {
        let base = computeSourceID(name: "Readr Test Source", lang: "en", type: .novel)
        #expect(computeSourceID(name: "Other Source", lang: "en", type: .novel) != base)
        #expect(computeSourceID(name: "Readr Test Source", lang: "pt-BR", type: .novel) != base)
        #expect(computeSourceID(name: "Readr Test Source", lang: "en", type: .manhwa) != base)
    }

    @Test("Components cannot be shifted across the separator")
    func componentsAreDelimited() {
        // Without a delimiter these would collide, and two different sources would
        // share a storage key.
        #expect(
            computeSourceID(name: "ab", lang: "c", type: .novel)
                != computeSourceID(name: "a", lang: "bc", type: .novel)
        )
    }
}
