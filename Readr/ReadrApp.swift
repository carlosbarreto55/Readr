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
    private let container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.appContainer, container)
        }
    }
}
