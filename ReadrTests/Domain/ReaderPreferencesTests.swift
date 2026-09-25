import Foundation
import Testing

@testable import Readr

@Suite("Reader preferences")
struct ReaderPreferencesTests {

    @Test("An untouched store reads back the documented defaults")
    func defaults() {
        let preferences = InMemorySettingsStore().readerPreferences
        #expect(preferences == ReaderPreferences())
        #expect(preferences.theme == .system)
        #expect(preferences.fontDesign == .system)
        #expect(preferences.textScale == 1)
        #expect(preferences.pageLayout == .vertical)
        #expect(preferences.mangaPageLayout == .paged)
    }

    @Test("Preferences written are read back")
    func roundTrip() {
        let store = InMemorySettingsStore()
        let written = ReaderPreferences(
            theme: .sepia, fontDesign: .serif, textScale: 1.5, pageLayout: .paged,
            mangaPageLayout: .vertical)
        store.setReaderPreferences(written)
        #expect(store.readerPreferences == written)
    }

    @Test("Text scale is clamped to the offered range and step")
    func clamping() {
        #expect(ReaderPreferences.clampedScale(5) == 2)
        #expect(ReaderPreferences.clampedScale(0.1) == 0.8)
        #expect(abs(ReaderPreferences.clampedScale(1.23) - 1.2) < 0.0001)
        #expect(ReaderPreferences.clampedScale(.nan) == 1)
        #expect(ReaderPreferences(textScale: 9).textScale == 2)
    }

    @Test("An unreadable stored theme falls back to the default")
    func unreadableFallsBack() {
        let store = InMemorySettingsStore()
        store.set("neon", for: SettingKey(ReaderSettingKeys.theme.name, default: ""))
        #expect(store.readerPreferences.theme == .system)
    }

    @Test("Reader keys live in the settings namespace, so a reset clears them")
    func namespaced() {
        let store = InMemorySettingsStore()
        store.setReaderPreferences(ReaderPreferences(theme: .dark))
        store.removeAll()
        #expect(store.readerPreferences.theme == .system)
    }
}
