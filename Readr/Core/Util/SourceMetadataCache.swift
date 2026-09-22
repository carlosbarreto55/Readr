import Foundation

/// A bounded, expiring, in-memory cache of source responses.
///
/// `source-metadata-cache` fixes the three properties: entries carry an explicit
/// expiry, the cache has a maximum entry count, and the least recently used entry
/// is evicted beyond it. What it caches is a *parsed* value, not bytes — the
/// expensive part of a catalog page is the parse, which is why `URLCache` would
/// not have satisfied this.
///
/// An `actor` rather than a locked struct: every caller is already `async`, and
/// check-expiry-then-read has to be atomic. An actor gives that without a lock
/// this codebase would otherwise have to reason about.
actor SourceMetadataCache<Value: Sendable> {
    private let maxEntries: Int
    private let lifetime: Duration
    private let now: @Sendable () -> ContinuousClock.Instant

    private struct Entry {
        let value: Value
        let storedAt: ContinuousClock.Instant
    }

    private var entries: [String: Entry] = [:]

    private struct Loads {
        var latest: UInt64
        var active: Set<UInt64>
    }

    /// In-flight loads by key. A newer refresh supersedes an older miss even if
    /// the older network request finishes last.
    private var loads: [String: Loads] = [:]
    private var nextLoadID: UInt64 = 0

    /// Keys in least-recently-used order. Read and write both move a key to the
    /// end, so the eviction victim is always `first`.
    ///
    /// An array rather than an ordered dictionary: these caches hold tens of
    /// entries, where the linear removal is cheaper than the bookkeeping a linked
    /// structure would need.
    private var recency: [String] = []

    /// - Parameters:
    ///   - maxEntries: The fixed maximum number of entries retained.
    ///   - lifetime: How long each stored value remains valid.
    ///   - now: Injected so expiry is tested by advancing a clock rather than by
    ///     sleeping. A test that sleeps for a five-minute TTL is a test nobody
    ///     runs.
    init(
        maxEntries: Int,
        lifetime: Duration,
        now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now }
    ) {
        precondition(
            maxEntries > 0,
            "A cache bounded at \(maxEntries) entries would store nothing.")
        precondition(
            lifetime > .zero,
            "A lifetime of \(lifetime) would expire every entry at once.")
        self.maxEntries = maxEntries
        self.lifetime = lifetime
        self.now = now
    }

    /// The cached value for `key`, or `nil` if it is absent or expired.
    ///
    /// An expired entry is removed on the way out rather than left to be evicted:
    /// otherwise a cache full of expired entries evicts live ones to make room.
    func value(for key: String) -> Value? {
        guard let entry = entries[key] else { return nil }
        guard now() - entry.storedAt < lifetime else {
            remove(key)
            return nil
        }
        touch(key)
        return entry.value
    }

    /// Stores `value`, evicting the least recently used entry if that overflows.
    func store(_ value: Value, for key: String) {
        write(value, for: key)
    }

    /// Marks a load as the newest request allowed to populate `key`.
    func beginLoad(for key: String) -> UInt64 {
        nextLoadID &+= 1
        let id = nextLoadID
        var state = loads[key] ?? Loads(latest: id, active: [])
        state.latest = id
        state.active.insert(id)
        loads[key] = state
        return id
    }

    /// Stores only when this load has not been superseded by a newer one.
    func storeIfLatest(_ value: Value, for key: String, loadID: UInt64) {
        guard var state = loads[key] else { return }
        state.active.remove(loadID)
        if state.latest == loadID {
            write(value, for: key)
        }
        loads[key] = state.active.isEmpty ? nil : state
    }

    /// Completes a failed load without replacing the last successful value.
    func finishLoad(for key: String, loadID: UInt64) {
        guard var state = loads[key] else { return }
        state.active.remove(loadID)
        loads[key] = state.active.isEmpty ? nil : state
    }

    private func write(_ value: Value, for key: String) {
        entries[key] = Entry(value: value, storedAt: now())
        touch(key)

        while recency.count > maxEntries, let victim = recency.first {
            remove(victim)
        }
    }

    /// Empties the cache.
    ///
    /// Called on a memory warning, by the composition root. The observer lives
    /// there rather than here so this type imports no UIKit and owns no lifecycle
    /// — and so that clearing it in a test needs no fake notification.
    func removeAll() {
        entries.removeAll()
        recency.removeAll()
        loads.removeAll()
    }

    var count: Int { entries.count }

    private func touch(_ key: String) {
        recency.removeAll { $0 == key }
        recency.append(key)
    }

    private func remove(_ key: String) {
        entries[key] = nil
        recency.removeAll { $0 == key }
    }
}
