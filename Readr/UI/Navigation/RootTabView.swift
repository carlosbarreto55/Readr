import SwiftUI

/// The app shell: four top-level destinations, each owning its own navigation
/// stack.
///
/// A `TabView` rather than the navigation drawer the Android app this descends
/// from uses — see `architecture.md` §9. Series and Reader are destinations, not
/// tabs.
struct RootTabView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigation = NavigationState()
    @State private var activationRefresh = RefreshThrottle(minimumInterval: 15 * 60)

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            Tab(AppTab.library.title, systemImage: AppTab.library.systemImage, value: .library) {
                NavigationStack(path: $navigation.libraryPath) {
                    LibraryScreen()
                        .navigationDestination(for: LibraryRoute.self) { route in
                            switch route {
                            case .series(let id):
                                SeriesScreen(id: id)
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
                                SeriesScreen(id: id)
                            }
                        }
                }
            }

            Tab(
                AppTab.downloads.title, systemImage: AppTab.downloads.systemImage, value: .downloads
            ) {
                NavigationStack(path: $navigation.downloadsPath) {
                    PlaceholderDestination(tab: .downloads)
                        .navigationDestination(for: DownloadsRoute.self) { route in
                            switch route {
                            case .series(let id):
                                SeriesScreen(id: id)
                            }
                        }
                }
            }

            Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: .settings) {
                NavigationStack(path: $navigation.settingsPath) {
                    SettingsScreen()
                }
            }
        }
        .environment(navigation)
        .fullScreenCover(item: $navigation.presentedReader) { route in
            ReaderScreen(route: route)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            refreshLibraryIfDue()
        }
    }

    /// The foreground refresh `architecture.md` §8 names as the actual
    /// guarantee: background refresh may never run.
    private func refreshLibraryIfDue() {
        guard let container, activationRefresh.claim() else { return }
        let series = container.series
        Task {
            let report = await series.refreshLibrary()
            if report.refreshed > 0 {
                navigation.libraryDidChange()
            }
        }
    }
}

#Preview {
    if let container = try? AppContainer.inMemory() {
        RootTabView()
            .environment(\.appContainer, container)
    }
}
