import Foundation
import Observation

@Observable
@MainActor
final class SettingsModel {
    private let settings: any SettingsStore
    private let catalog: any CatalogRepository

    private(set) var state: SettingsState

    init(settings: any SettingsStore, catalog: any CatalogRepository, appVersion: String) {
        self.settings = settings
        self.catalog = catalog
        state = SettingsState(preferences: settings.readerPreferences, appVersion: appVersion)
    }

    func onAction(_ action: SettingsAction) {
        switch action {
        case .appeared:
            // Another screen — the Reader — may have changed these since.
            state.preferences = settings.readerPreferences
            Task { await loadSources() }
        case .setTheme(let theme):
            update { $0.theme = theme }
        case .setFontDesign(let design):
            update { $0.fontDesign = design }
        case .setTextScale(let scale):
            update { $0.textScale = ReaderPreferences.clampedScale(scale) }
        case .setPageLayout(let layout):
            update { $0.pageLayout = layout }
        case .requestReset:
            state.isResetConfirmationPresented = true
        case .cancelReset:
            state.isResetConfirmationPresented = false
        case .confirmReset:
            state.isResetConfirmationPresented = false
            // Settings only. The library and every chapter's progress live in the
            // store, which this never touches (`preferences-store`).
            settings.removeAll()
            state.preferences = settings.readerPreferences
        }
    }

    func loadSources() async {
        state.sources = await catalog.sources()
    }

    private func update(_ change: (inout ReaderPreferences) -> Void) {
        change(&state.preferences)
        settings.setReaderPreferences(state.preferences)
    }
}
