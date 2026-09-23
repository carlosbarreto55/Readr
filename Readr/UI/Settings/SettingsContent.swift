import SwiftUI

struct SettingsContent: View {
    let state: SettingsState
    let onAction: (SettingsAction) -> Void

    var body: some View {
        Form {
            readerSection
            sourcesSection
            Section {
                Button("Reset Settings", role: .destructive) { onAction(.requestReset) }
            } footer: {
                Text(
                    "Restores reader and library display settings to their defaults. "
                        + "Your library and reading progress are not affected.")
            }
            Section {
                LabeledContent("Version", value: state.appVersion)
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Reset all settings?",
            isPresented: Binding(
                get: { state.isResetConfirmationPresented },
                set: { if !$0 { onAction(.cancelReset) } }),
            titleVisibility: .visible
        ) {
            Button("Reset Settings", role: .destructive) { onAction(.confirmReset) }
            Button("Cancel", role: .cancel) { onAction(.cancelReset) }
        } message: {
            Text("Your library and reading progress are kept.")
        }
    }

    private var readerSection: some View {
        Section("Reader") {
            Picker(
                "Theme",
                selection: Binding(
                    get: { state.preferences.theme }, set: { onAction(.setTheme($0)) })
            ) {
                ForEach(ReaderTheme.allCases) { Text($0.title).tag($0) }
            }
            Picker(
                "Novel Font",
                selection: Binding(
                    get: { state.preferences.fontDesign }, set: { onAction(.setFontDesign($0)) })
            ) {
                ForEach(ReaderFontDesign.allCases) { Text($0.title).tag($0) }
            }
            Stepper(
                value: Binding(
                    get: { state.preferences.textScale }, set: { onAction(.setTextScale($0)) }),
                in: ReaderPreferences.textScaleRange,
                step: ReaderPreferences.textScaleStep
            ) {
                LabeledContent(
                    "Novel Text Size",
                    value: "\(Int((state.preferences.textScale * 100).rounded()))%")
            }
            Picker(
                "Manhwa Layout",
                selection: Binding(
                    get: { state.preferences.pageLayout }, set: { onAction(.setPageLayout($0)) })
            ) {
                ForEach(ReaderPageLayout.allCases) { Text($0.title).tag($0) }
            }
        }
    }

    private var sourcesSection: some View {
        Section("Sources") {
            if state.sources.isEmpty {
                Text("No sources are registered.")
                    .foregroundStyle(Palette.secondaryLabel)
            }
            ForEach(state.sources) { source in
                LabeledContent {
                    Text(source.contentType == .novel ? "Novels" : "Manhwa")
                } label: {
                    Text(source.name)
                    Text(source.baseURL.host() ?? source.baseURL.absoluteString)
                        .font(Typography.caption)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsContent(
            state: SettingsState(
                preferences: ReaderPreferences(theme: .sepia, textScale: 1.2),
                sources: [
                    SourceInfo(
                        id: 1, name: "AsuraScans", lang: "en",
                        baseURL: URL(string: "https://asuracomic.net")!, contentType: .manhwa),
                    SourceInfo(
                        id: 2, name: "FreeWebNovel", lang: "en",
                        baseURL: URL(string: "https://freewebnovel.com")!, contentType: .novel)
                ],
                appVersion: "0.1.0 (1)"),
            onAction: { _ in })
    }
}
