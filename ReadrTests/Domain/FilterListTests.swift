import Testing

@testable import Readr

@Suite("FilterList")
struct FilterListTests {

    @Test("An empty filter list is representable")
    func emptyIsRepresentable() {
        #expect(FilterList.none.isEmpty)
        #expect(FilterList().filters.isEmpty)
    }

    @Test("A filter list keeps the filters it was given, in order")
    func keepsOrder() {
        let list: FilterList = [.genre("Fantasy"), .status(.ongoing), .sort("latest")]
        #expect(list.filters == [.genre("Fantasy"), .status(.ongoing), .sort("latest")])
        #expect(list.isEmpty == false)
    }

    @Test("Filters comparing equal describe the same restriction")
    func equality() {
        #expect(Filter.genre("Fantasy") == Filter.genre("Fantasy"))
        #expect(Filter.genre("Fantasy") != Filter.genre("Horror"))
        #expect(Filter.genre("Fantasy") != Filter.sort("Fantasy"))
    }
}
