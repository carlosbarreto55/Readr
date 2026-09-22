import SwiftUI

/// Application entry point.
///
/// This is intentionally the only Swift file in the repository. The project is a
/// documented skeleton: `architecture.md` defines the layers, `codemap.md` maps the
/// directories, and `openspec/specs/` holds the normative capability specs — but no
/// feature code exists yet.
///
/// The first implementation change is `openspec/changes/add-source-contract/`.
/// See `AGENTS.md` before adding anything here.
@main
struct ReadrApp: App {
    var body: some Scene {
        WindowGroup {
            PlaceholderRootView()
        }
    }
}

/// Temporary root. Replaced by the `TabView` app shell in `UI/Navigation/`
/// once the first screens land.
private struct PlaceholderRootView: View {
    var body: some View {
        ContentUnavailableView(
            "Readr",
            systemImage: "books.vertical",
            description: Text("Skeleton build. No features implemented yet.")
        )
    }
}
