import SwiftUI

/// The app shell: four top-level destinations, each owning its own navigation
/// stack.
///
/// A `TabView` rather than the navigation drawer the Android app this descends
/// from uses — see `architecture.md` §9. Series and Reader are destinations, not
/// tabs.
struct RootTabView: View {
    @State private var navigation = NavigationState()

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            Tab(AppTab.library.title, systemImage: AppTab.library.systemImage, value: .library) {
                NavigationStack(path: $navigation.libraryPath) {
                    LibraryScreen()
                        .navigationDestination(for: LibraryRoute.self) { route in
                            switch route {
                            case .series(let id):
                                PendingSeriesDestination(id: id)
                            }
                        }
                }
            }

            Tab(AppTab.browse.title, systemImage: AppTab.browse.systemImage, value: .browse) {
                NavigationStack(path: $navigation.browsePath) {
                    BrowseScreen()
                        .navigationDestination(for: BrowseRoute.self) { route in
                            switch route {
                            case .catalog(let sourceID):
                                BrowseScreen(sourceID: sourceID)
                            case .series(let id):
                                PendingSeriesDestination(id: id)
                            }
                        }
                }
            }

            Tab(
                AppTab.downloads.title, systemImage: AppTab.downloads.systemImage, value: .downloads
            ) {
                NavigationStack(path: $navigation.downloadsPath) {
                    PlaceholderDestination(tab: .downloads)
                }
            }

            Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: .settings) {
                NavigationStack(path: $navigation.settingsPath) {
                    PlaceholderDestination(tab: .settings)
                }
            }
        }
        .environment(navigation)
    }
}

/// M5's typed landing point for a route whose full screen arrives in M6.
private struct PendingSeriesDestination: View {
    let id: SeriesID

    var body: some View {
        ContentUnavailableView {
            Label("Series Details", systemImage: "book.pages")
        } description: {
            Text("This catalog route is ready. Series details and chapters arrive in M6.")
        }
        .navigationTitle("Series")
        .accessibilityIdentifier(id.url.absoluteString)
    }
}

#Preview {
    if let container = try? AppContainer.inMemory() {
        RootTabView()
            .environment(\.appContainer, container)
    }
}
