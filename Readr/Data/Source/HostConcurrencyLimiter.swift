import Foundation

/// Bounds how many requests may be in flight against one host at a time.
///
/// `source-request-performance` requires the bound to apply *per source,
/// independently*. It is held per host rather than per `sourceID` because the
/// limit exists to protect the site, and two sources served from one host should
/// share one budget rather than each getting a full one.
///
/// Built on continuations, never `DispatchSemaphore`: a semaphore would block a
/// cooperative-pool thread, which invariant 7 forbids and which on a small pool
/// can deadlock every other request in the app.
actor HostConcurrencyLimiter {
    private let limit: Int
    private var active: [String: Int] = [:]
    private var waiting: [String: [CheckedContinuation<Void, Never>]] = [:]

    /// The high-water mark per host. Kept so a test can assert the bound held
    /// under load — a limiter that is merely *usually* right is indistinguishable
    /// from a correct one until a site starts refusing requests.
    private(set) var peak: [String: Int] = [:]

    init(limit: Int) {
        precondition(limit > 0, "A concurrency limit of \(limit) would admit nothing.")
        self.limit = limit
    }

    /// Runs `body` holding a permit for `host`, releasing it however `body` ends.
    ///
    /// `release` is synchronous and actor-isolated, which is what lets it run
    /// from a `defer` — an `async` release could not, and a `Task { }` in the
    /// defer would release after an unrelated acquire had already been admitted.
    func withPermit<T: Sendable>(
        host: String,
        _ body: @Sendable () async throws -> T
    ) async rethrows -> T {
        await acquire(host: host)
        defer { release(host: host) }
        // Suspending here frees the actor, so other hosts — and other permits for
        // this one — proceed while this request is in flight.
        return try await body()
    }

    func peakConcurrency(for host: String) -> Int { peak[host] ?? 0 }

    private func acquire(host: String) async {
        let current = active[host] ?? 0
        if current < limit {
            active[host] = current + 1
            peak[host] = max(peak[host] ?? 0, current + 1)
            return
        }
        await withCheckedContinuation { continuation in
            // Runs on the actor before suspension, so a permit released between
            // the check above and this line cannot be missed.
            waiting[host, default: []].append(continuation)
        }
    }

    private func release(host: String) {
        if var queue = waiting[host], !queue.isEmpty {
            // Hand the permit straight to the next waiter. `active` is unchanged
            // because the count never dipped — which is also why this cannot
            // transiently admit a request over the limit.
            let next = queue.removeFirst()
            waiting[host] = queue.isEmpty ? nil : queue
            next.resume()
            return
        }
        let remaining = (active[host] ?? 1) - 1
        active[host] = remaining > 0 ? remaining : nil
    }
}
