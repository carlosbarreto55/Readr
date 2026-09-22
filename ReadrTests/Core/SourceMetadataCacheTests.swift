import Foundation
import Testing

@testable import Readr

@Suite("SourceMetadataCache")
struct SourceMetadataCacheTests {

    /// A clock a test advances by hand. Expiry tested by sleeping for a
    /// five-minute TTL is expiry that is never tested.
    private final class TestClock: @unchecked Sendable {
        private let lock = NSLock()
        private var offset: Duration = .zero
        private let origin = ContinuousClock.now

        var now: @Sendable () -> ContinuousClock.Instant {
            { [self] in lock.withLock { origin.advanced(by: offset) } }
        }

        func advance(by duration: Duration) {
            lock.withLock { offset += duration }
        }
    }

    @Test("A stored value reads back")
    func storeAndRead() async {
        let cache = SourceMetadataCache<String>(maxEntries: 4, lifetime: .seconds(60))
        await cache.store("value", for: "key")
        #expect(await cache.value(for: "key") == "value")
    }

    @Test("An absent key is nil rather than an error")
    func missIsNil() async {
        let cache = SourceMetadataCache<String>(maxEntries: 4, lifetime: .seconds(60))
        #expect(await cache.value(for: "never stored") == nil)
    }

    @Test("An entry past its lifetime is discarded")
    func expiredEntryIsDiscarded() async {
        let clock = TestClock()
        let cache = SourceMetadataCache<String>(
            maxEntries: 4, lifetime: .seconds(60), now: clock.now)

        await cache.store("value", for: "key")
        clock.advance(by: .seconds(59))
        #expect(await cache.value(for: "key") == "value")

        clock.advance(by: .seconds(2))
        #expect(await cache.value(for: "key") == nil)
        // Dropped on read rather than left to be evicted — otherwise a cache full
        // of expired entries evicts live ones to make room for new ones.
        #expect(await cache.count == 0)
    }

    @Test("At capacity, the least recently used entry is evicted")
    func evictsLeastRecentlyUsed() async {
        let cache = SourceMetadataCache<String>(maxEntries: 3, lifetime: .seconds(600))
        await cache.store("a", for: "a")
        await cache.store("b", for: "b")
        await cache.store("c", for: "c")

        await cache.store("d", for: "d")

        #expect(await cache.value(for: "a") == nil)
        #expect(await cache.value(for: "b") == "b")
        #expect(await cache.value(for: "c") == "c")
        #expect(await cache.value(for: "d") == "d")
        #expect(await cache.count == 3)
    }

    /// Least *recently used*, not least recently stored. A reader paging back and
    /// forth across a catalog reads old entries constantly, and evicting the ones
    /// they keep returning to would defeat the cache exactly where it helps most.
    @Test("Reading an entry makes it recent")
    func readingRefreshesRecency() async {
        let cache = SourceMetadataCache<String>(maxEntries: 3, lifetime: .seconds(600))
        await cache.store("a", for: "a")
        await cache.store("b", for: "b")
        await cache.store("c", for: "c")

        _ = await cache.value(for: "a")
        await cache.store("d", for: "d")

        #expect(await cache.value(for: "a") == "a")
        #expect(await cache.value(for: "b") == nil)
    }

    @Test("Re-storing a key does not grow the cache")
    func restoringDoesNotDuplicate() async {
        let cache = SourceMetadataCache<String>(maxEntries: 2, lifetime: .seconds(600))
        await cache.store("first", for: "key")
        await cache.store("second", for: "key")

        #expect(await cache.count == 1)
        #expect(await cache.value(for: "key") == "second")
    }

    @Test("An older load finishing last cannot overwrite a newer refresh")
    func supersededLoadCannotOverwrite() async {
        let cache = SourceMetadataCache<String>(maxEntries: 2, lifetime: .seconds(600))
        let older = await cache.beginLoad(for: "key")
        let newer = await cache.beginLoad(for: "key")

        await cache.storeIfLatest("fresh", for: "key", loadID: newer)
        await cache.storeIfLatest("stale", for: "key", loadID: older)

        #expect(await cache.value(for: "key") == "fresh")
    }

    @Test("Clearing empties it")
    func clearEmpties() async {
        let cache = SourceMetadataCache<String>(maxEntries: 4, lifetime: .seconds(600))
        await cache.store("a", for: "a")
        await cache.store("b", for: "b")

        await cache.removeAll()

        #expect(await cache.count == 0)
        #expect(await cache.value(for: "a") == nil)
    }
}
