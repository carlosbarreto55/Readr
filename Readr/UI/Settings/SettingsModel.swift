import Foundation
import Observation

@Observable
@MainActor
final class SettingsModel {
    private let settings: any SettingsStore
    private let catalog: any CatalogRepository
    private let downloads: any DownloadRepository

    private(set) var state: SettingsState

    init(
        settings: any SettingsStore,
        catalog: any CatalogRepository,
        downloads: any DownloadRepository,
        appVersion: String
    ) {
        self.settings = settings
        self.catalog = catalog
        self.downloads = downloads
        state = SettingsState(preferences: settings.readerPreferences, appVersion: appVersion)
    }

    func onAction(_ action: SettingsAction) {
        switch action {
        case .appeared:
            // Another screen — the Reader — may have changed these since.
            state.preferences = settings.readerPreferences
            Task {
                await loadSources()
                await loadStorage()
            }
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
        case .requestDeleteDownloads, .cancelDeleteDownloads, .confirmDeleteDownloads:
            handleDownloads(action)
        }
    }

    private func handleDownloads(_ action: SettingsAction) {
        state.isDeleteDownloadsConfirmationPresented = action == .requestDeleteDownloads
        if action == .confirmDeleteDownloads {
            Task { await deleteDownloads() }
        }
    }

    func loadStorage() async {
        state.storageBytes = (try? await downloads.snapshot().storageBytes) ?? state.storageBytes
    }

    func deleteDownloads() async {
        try? await downloads.deleteAll()
        await loadStorage()
    }

    func loadSources() async {
        state.sources = await catalog.sources()
    }

    private func update(_ change: (inout ReaderPreferences) -> Void) {
        change(&state.preferences)
        settings.setReaderPreferences(state.preferences)
    }
}
