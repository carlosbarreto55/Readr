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

    /// The app theme, built with the container so the first frame already has
    /// it. `nil` only when the store could not be opened.
    @State private var appearance: AppAppearanceModel?

    @Environment(\.scenePhase) private var scenePhase

    init() {
        container = Result { try AppContainer.live() }
        if case .success(let container) = container {
            _appearance = State(initialValue: AppAppearanceModel(settings: container.settings))
            // Before launch completes, or the scheduler refuses the handlers.
            BackgroundTasks.register(container: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let container):
                RootTabView()
                    .environment(\.appContainer, container)
                    .environment(\.appAppearance, appearance)
                    .preferredColorScheme(appearance?.colorScheme)
            case .failure(let error):
                StoreUnavailableView(error: error)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background, case .success(let container) = container else { return }
            Task { await BackgroundTasks.schedule(container: container) }
        }
    }
}
