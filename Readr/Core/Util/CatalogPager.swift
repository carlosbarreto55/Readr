import Foundation

/// Pages forward through a catalog, accumulating entries.
///
/// `source-listing-pagination` is a state machine, not a view: accumulate in
/// order, discard an entry already loaded, refuse a second request while one is
/// in flight, and clear the in-flight flag on failure so the *same* page can be
/// retried. This is that machine.
///
/// It is driven by a closure rather than a repository, so it names no source, no
/// registry, and no framework — which is what lets every rule above be tested
/// without a network, a parser, or a screen. A screen owns one and reads `state`.
@MainActor
final class CatalogPager {

    /// What a catalog surface needs to render.
    struct State: Sendable, Equatable {
        /// Every entry loaded so far, in the order the source returned them.
        var entries: [Series] = []
        /// A request is in flight. A surface shows a spinner; it must not also
        /// issue another request.
        var isLoading = false
        /// Further pages exist. `false` means stop asking.
        var hasMore = true
        /// The last failure, still unacknowledged. Cleared when a request starts.
        var failure: (any Error)?

        /// Nothing loaded, nothing pending, nothing wrong — the state an empty
        /// catalog is in, which a surface must not present as an error.
        var isEmpty: Bool { entries.isEmpty && !isLoading && failure == nil }

        static func == (lhs: State, rhs: State) -> Bool {
            lhs.entries == rhs.entries
                && lhs.isLoading == rhs.isLoading
                && lhs.hasMore == rhs.hasMore
                && (lhs.failure == nil) == (rhs.failure == nil)
        }
    }

    private(set) var state = State()

    /// The page index to request next. Not advanced until a page *succeeds*, so
    /// a retry after a failure re-requests the same index rather than skipping it.
    private var nextPage = 1

    /// Identities already accumulated, so a duplicate is discarded in constant
    /// time rather than by scanning `entries` — sites repeat entries across page
    /// boundaries routinely when the underlying list shifts between requests.
    private var loaded: Set<SeriesID> = []

    private let fetch: @Sendable (Int) async throws -> SeriesPage

    /// - Parameter fetch: loads one page, 1-based. Throws to signal failure; an
    ///   empty page is not a failure.
    init(fetch: @escaping @Sendable (Int) async throws -> SeriesPage) {
        self.fetch = fetch
    }

    /// Loads the first page.
    ///
    /// `source-listing-pagination` requires an opened catalog to request page 1,
    /// so this resets rather than continuing from wherever a previous run stopped.
    func loadFirstPage() async {
        guard !state.isLoading else { return }
        reset()
        await load()
    }

    /// Loads the next page, if there is one and nothing is pending.
    ///
    /// Silently does nothing when a request is already in flight — this is called
    /// from a scroll handler, which fires far faster than a request completes, and
    /// the spec requires exactly one request to remain in flight.
    func loadNextPage() async {
        guard !state.isLoading, state.hasMore else { return }
        await load()
    }

    /// Re-requests the page that failed.
    ///
    /// `nextPage` was never advanced past it, so this is `load()` — the retry
    /// re-requests the same index by construction rather than by remembering one.
    func retry() async {
        guard !state.isLoading else { return }
        await load()
    }

    /// Discards everything and reloads from page 1, ignoring what is loaded.
    ///
    /// The pull-to-refresh path. The caller's `fetch` closure is what decides
    /// whether the *cache* is bypassed; this only decides that the accumulated
    /// list starts over.
    func refresh() async {
        guard !state.isLoading else { return }
        reset()
        await load()
    }

    private func reset() {
        state = State()
        nextPage = 1
        loaded.removeAll()
    }

    private func load() async {
        state.isLoading = true
        state.failure = nil

        do {
            let page = try await fetch(nextPage)
            // Appended in source order, with an entry already loaded discarded
            // rather than appended — the two rules that keep a catalog from
            // growing duplicates as it pages.
            for entry in page.entries where loaded.insert(entry.id).inserted {
                state.entries.append(entry)
            }
            state.hasMore = page.hasMore
            nextPage += 1
        } catch {
            // The flag clears on failure, or a catalog that failed once would
            // refuse every later request and appear stalled rather than broken.
            state.failure = error
        }

        state.isLoading = false
    }
}
