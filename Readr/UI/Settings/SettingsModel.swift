import Foundation
import Observation

@Observable
@MainActor
final class SettingsModel {
    private let settings: any SettingsStore
    private let appearance: AppAppearanceModel
    private let catalog: any CatalogRepository
    private let downloads: any DownloadRepository
    private let systemSearch: any SystemSearchRepository

    private(set) var state: SettingsState

    init(
        settings: any SettingsStore,
        appearance: AppAppearanceModel,
        catalog: any CatalogRepository,
        downloads: any DownloadRepository,
        systemSearch: any SystemSearchRepository,
        appVersion: String
    ) {
        self.settings = settings
        self.appearance = appearance
        self.catalog = catalog
        self.downloads = downloads
        self.systemSearch = systemSearch
        state = SettingsState(
            appTheme: appearance.theme, preferences: settings.readerPreferences,
            appVersion: appVersion)
    }

    func onAction(_ action: SettingsAction) {
        switch action {
        case .appeared:
            // Another screen — the Reader — may have changed these since.
            state.preferences = settings.readerPreferences
            state.appTheme = appearance.theme
            Task {
                await loadSources()
                await loadStorage()
            }
        case .setAppTheme, .setReaderTheme:
            updateTheme(action)
        case .setFontDesign(let design):
            update { $0.fontDesign = design }
        case .setTextScale(let scale):
            update { $0.textScale = ReaderPreferences.clampedScale(scale) }
        case .setPageLayout, .setMangaPageLayout, .setComicPageLayout:
            updateLayout(action)
        case .requestReset:
            state.isResetConfirmationPresented = true
        case .cancelReset:
            state.isResetConfirmationPresented = false
        case .confirmReset:
            state.isResetConfirmationPresented = false
            // Settings only. The library and every chapter's progress live in the
            // store, which this never touches (`preferences-store`).
            settings.removeAll()
            appearance.reload()
            state.appTheme = appearance.theme
            state.preferences = settings.readerPreferences
        case .requestDeleteDownloads, .cancelDeleteDownloads, .confirmDeleteDownloads:
            handleDownloads(action)
        case .rebuildSearchIndex:
            Task { await rebuildSearchIndex() }
        }
    }

    private func handleDownloads(_ action: SettingsAction) {
        state.isDeleteDownloadsConfirmationPresented = action == .requestDeleteDownloads
        if action == .confirmDeleteDownloads {
            Task { await deleteDownloads() }
        }
    }

    /// Replaces the Spotlight index with one derived from the library.
    func rebuildSearchIndex() async {
        guard !state.isRebuildingSearchIndex else { return }
        state.isRebuildingSearchIndex = true
        await systemSearch.rebuildIndex()
        state.isRebuildingSearchIndex = false
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

    private func updateTheme(_ action: SettingsAction) {
        switch action {
        case .setAppTheme(let theme):
            // Through the appearance model, so the whole app restyles now.
            appearance.set(theme)
            state.appTheme = theme
        case .setReaderTheme(let theme):
            update { $0.theme = theme }
        default:
            break
        }
    }

    private func updateLayout(_ action: SettingsAction) {
        switch action {
        case .setPageLayout(let layout):
            update { $0.pageLayout = layout }
        case .setMangaPageLayout(let layout):
            update { $0.mangaPageLayout = layout }
        case .setComicPageLayout(let layout):
            update { $0.comicPageLayout = layout }
        default:
            break
        }
    }
}
