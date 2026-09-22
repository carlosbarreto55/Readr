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
                    PlaceholderDestination(tab: .library)
                }
            }

            Tab(AppTab.browse.title, systemImage: AppTab.browse.systemImage, value: .browse) {
                NavigationStack(path: $navigation.browsePath) {
                    PlaceholderDestination(tab: .browse)
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

#Preview {
    RootTabView()
}
