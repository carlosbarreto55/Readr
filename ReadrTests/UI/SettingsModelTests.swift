import Foundation
import Testing

@testable import Readr

@Suite("SettingsModel")
@MainActor
struct SettingsModelTests {
    private let source = SourceInfo(
        id: 1, name: "Source", lang: "en", baseURL: URL(string: "https://example.test")!,
        contentType: .novel)

    private func make(
        _ settings: InMemorySettingsStore,
        downloads: FakeDownloadRepository = FakeDownloadRepository(),
        systemSearch: RecordingSystemSearchRepository = RecordingSystemSearchRepository()
    ) -> SettingsModel {
        SettingsModel(
            settings: settings, catalog: ScriptedCatalogRepository(sources: [source]),
            downloads: downloads, systemSearch: systemSearch, appVersion: "1.0 (1)")
    }

    @Test("Reader appearance changes persist through the settings store")
    func changesPersist() {
        let settings = InMemorySettingsStore()
        let model = make(settings)

        model.onAction(.setTheme(.dark))
        model.onAction(.setFontDesign(.serif))
        model.onAction(.setTextScale(1.4))
        model.onAction(.setPageLayout(.paged))
        model.onAction(.setMangaPageLayout(.vertical))

        let stored = settings.readerPreferences
        #expect(stored.theme == .dark)
        #expect(stored.fontDesign == .serif)
        #expect(abs(stored.textScale - 1.4) < 0.0001)
        #expect(stored.pageLayout == .paged)
        #expect(stored.mangaPageLayout == .vertical)
        #expect(model.state.preferences == stored)
    }

    @Test("Appearing re-reads preferences another screen changed, and lists sources")
    func appearingRefreshes() async {
        let settings = InMemorySettingsStore()
        let model = make(settings)
        settings.setReaderPreferences(ReaderPreferences(theme: .sepia))

        model.onAction(.appeared)
        await model.loadSources()

        #expect(model.state.preferences.theme == .sepia)
        #expect(model.state.sources.map(\.name) == ["Source"])
    }

    @Test("Reset asks first, then restores every setting to its default")
    func resetConfirmsThenClears() {
        let settings = InMemorySettingsStore()
        settings.setReaderPreferences(ReaderPreferences(theme: .dark))
        let model = make(settings)

        model.onAction(.requestReset)
        #expect(model.state.isResetConfirmationPresented)
        model.onAction(.cancelReset)
        #expect(settings.readerPreferences.theme == .dark)

        model.onAction(.requestReset)
        model.onAction(.confirmReset)
        #expect(!model.state.isResetConfirmationPresented)
        #expect(settings.readerPreferences == ReaderPreferences())
        #expect(model.state.preferences == ReaderPreferences())
    }

    @Test("Storage used is shown, and Delete All Downloads asks first and frees it")
    func storage() async throws {
        let downloads = FakeDownloadRepository(
            snapshot: DownloadQueueSnapshot(entries: [], storageBytes: 2_048))
        let model = make(InMemorySettingsStore(), downloads: downloads)

        await model.loadStorage()
        #expect(model.state.storageBytes == 2_048)

        model.onAction(.requestDeleteDownloads)
        #expect(model.state.isDeleteDownloadsConfirmationPresented)
        model.onAction(.confirmDeleteDownloads)

        try await waitUntil { model.state.storageBytes == 0 }
        #expect(await downloads.deleteAllCalls == 1)
    }

    @Test("Rebuild Spotlight Index rebuilds from the library")
    func rebuildIndex() async {
        let systemSearch = RecordingSystemSearchRepository()
        let model = make(InMemorySettingsStore(), systemSearch: systemSearch)

        await model.rebuildSearchIndex()

        #expect(await systemSearch.rebuildCalls == 1)
        #expect(!model.state.isRebuildingSearchIndex)
    }
}
