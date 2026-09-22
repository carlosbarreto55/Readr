import Foundation
import Testing

@testable import Readr

@Suite("SourceCacheKey")
struct SourceCacheKeyTests {
    private let url = URL(string: "https://example.test/series/one")!

    @Test("Different operations, sources, and pages get different keys")
    func distinctRequestsGetDistinctKeys() {
        let keys: Set<String> = [
            SourceCacheKey.popular(sourceID: 1, page: 1),
            SourceCacheKey.popular(sourceID: 1, page: 2),
            SourceCacheKey.popular(sourceID: 2, page: 1),
            SourceCacheKey.latest(sourceID: 1, page: 1),
            SourceCacheKey.details(
                for: Series(sourceID: 1, url: url, title: "One", contentType: .novel)),
            SourceCacheKey.chapters(sourceID: 1, url: url)
        ]
        #expect(keys.count == 6)
    }

    /// Without length prefixing, `"ab" + "c"` and `"a" + "bc"` serialize
    /// identically — so two genuinely different filter sets would share one cache
    /// entry and one catalog would be served under the other's query.
    @Test("Filter sets that would concatenate identically get different keys")
    func lengthPrefixingPreventsCollision() {
        let first = SourceCacheKey.search(
            sourceID: 1, query: "q", page: 1, filters: FilterList([.genre("ab"), .sort("c")]))
        let second = SourceCacheKey.search(
            sourceID: 1, query: "q", page: 1, filters: FilterList([.genre("a"), .sort("bc")]))

        #expect(first != second)
    }

    @Test("A query whose text differs gets a different key")
    func queriesAreDistinguished() {
        let first = SourceCacheKey.search(sourceID: 1, query: "one", page: 1, filters: .none)
        let second = SourceCacheKey.search(sourceID: 1, query: "two", page: 1, filters: .none)
        #expect(first != second)
    }

    @Test("Queries differing in case or whitespace remain distinct requests")
    func queriesArePreserved() {
        let plain = SourceCacheKey.search(sourceID: 1, query: "One Piece", page: 1, filters: .none)
        let messy = SourceCacheKey.search(
            sourceID: 1, query: "  one   piece ", page: 1, filters: .none)
        #expect(plain != messy)
    }

    @Test("Filter order remains part of the site-specific request")
    func filterOrderIsPreserved() {
        let one = SourceCacheKey.search(
            sourceID: 1, query: "q", page: 1,
            filters: FilterList([.genre("Action"), .status(.ongoing)]))
        let other = SourceCacheKey.search(
            sourceID: 1, query: "q", page: 1,
            filters: FilterList([.status(.ongoing), .genre("Action")]))
        #expect(one != other)
    }

    @Test("A different filter value changes the key")
    func filterValuesAreDistinguished() {
        let ongoing = SourceCacheKey.search(
            sourceID: 1, query: "q", page: 1, filters: FilterList([.status(.ongoing)]))
        let completed = SourceCacheKey.search(
            sourceID: 1, query: "q", page: 1, filters: FilterList([.status(.completed)]))
        #expect(ongoing != completed)
    }

    /// A genre named "ongoing" must not collide with a status of ongoing.
    @Test("Filter kinds are distinguished from one another")
    func filterKindsAreDistinguished() {
        let asGenre = SourceCacheKey.search(
            sourceID: 1, query: "q", page: 1, filters: FilterList([.genre("ongoing")]))
        let asStatus = SourceCacheKey.search(
            sourceID: 1, query: "q", page: 1, filters: FilterList([.status(.ongoing)]))
        #expect(asGenre != asStatus)
    }

    @Test("Two series on one source get different detail keys")
    func detailKeysFollowTheURL() {
        let other = URL(string: "https://example.test/series/two")!
        let first = Series(sourceID: 1, url: url, title: "One", contentType: .novel)
        let second = Series(sourceID: 1, url: other, title: "Two", contentType: .novel)
        #expect(SourceCacheKey.details(for: first) != SourceCacheKey.details(for: second))
    }

    @Test("Known metadata remains part of a detail request")
    func detailMetadataIsDistinguished() {
        let sparse = Series(sourceID: 1, url: url, title: "One", contentType: .novel)
        let richer = Series(
            sourceID: 1, url: url, title: "One", author: "Known", contentType: .novel)
        #expect(SourceCacheKey.details(for: sparse) != SourceCacheKey.details(for: richer))
    }
}
