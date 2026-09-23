import SwiftUI

struct SettingsScreen: View {
    @Environment(\.appContainer) private var container
    @State private var model: SettingsModel?

    var body: some View {
        Group {
            if let model {
                SettingsContent(state: model.state, onAction: model.onAction)
            } else if let container {
                ProgressView()
                    .task {
                        guard model == nil else { return }
                        model = SettingsModel(
                            settings: container.settings,
                            catalog: container.catalog,
                            downloads: container.downloads,
                            systemSearch: container.systemSearch,
                            appVersion: Self.appVersion)
                    }
            } else {
                ContentUnavailableView {
                    Label("Settings Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Readr’s app container was not installed in this view.")
                }
                .navigationTitle("Settings")
            }
        }
        .onAppear { model?.onAction(.appeared) }
        .onChange(of: model == nil) { model?.onAction(.appeared) }
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
