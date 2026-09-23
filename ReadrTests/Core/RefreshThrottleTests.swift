import Foundation
import Testing

@testable import Readr

@Suite("Refresh throttle")
struct RefreshThrottleTests {

    @Test("The first claim runs, a claim inside the interval does not, and one after it does")
    func throttles() {
        var throttle = RefreshThrottle(minimumInterval: 60)
        let start = Date(timeIntervalSince1970: 1_000)

        let first = throttle.claim(at: start)
        let tooSoon = throttle.claim(at: start.addingTimeInterval(59))
        let due = throttle.claim(at: start.addingTimeInterval(60))

        #expect(first)
        #expect(!tooSoon)
        #expect(due)
        #expect(throttle.lastRefresh == start.addingTimeInterval(60))
    }
}
