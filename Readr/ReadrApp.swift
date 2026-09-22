import SwiftUI

/// Application entry point.
///
/// Builds `AppContainer`, the composition root, and injects it into the SwiftUI
/// environment. Views never construct dependencies; presentation models receive
/// what they need through `init`.
///
/// See `AGENTS.md` before adding anything here.
@main
struct ReadrApp: App {
    /// Built once, for the lifetime of the process.
    ///
    /// Held as a `Result` so that a store that cannot be opened is shown to the
    /// reader rather than resolved by deleting their library.
    private let container: Result<AppContainer, any Error>

    init() {
        container = Result { try AppContainer.live() }
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let container):
                RootTabView()
                    .environment(\.appContainer, container)
            case .failure(let error):
                StoreUnavailableView(error: error)
            }
        }
    }
}
