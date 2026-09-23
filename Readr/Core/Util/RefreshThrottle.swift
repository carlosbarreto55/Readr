import Foundation

/// Decides whether an opportunistic refresh is due.
///
/// App activation happens constantly — every return from the app switcher — and
/// a library refresh fetches every saved series. The throttle is what keeps "the
/// foreground refresh is the guarantee" from becoming "every glance at the app
/// hits every site".
struct RefreshThrottle: Sendable {
    let minimumInterval: TimeInterval
    private(set) var lastRefresh: Date?

    init(minimumInterval: TimeInterval) {
        self.minimumInterval = minimumInterval
    }

    /// Whether a refresh should run at `now`. Records it when it should.
    mutating func claim(at now: Date = .now) -> Bool {
        if let lastRefresh, now.timeIntervalSince(lastRefresh) < minimumInterval {
            return false
        }
        lastRefresh = now
        return true
    }
}
