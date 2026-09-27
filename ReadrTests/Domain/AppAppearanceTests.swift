import Foundation
import Testing

@testable import Readr

@Suite("App appearance")
struct AppAppearanceTests {

    @Test("An untouched store reads back System")
    func defaults() {
        #expect(InMemorySettingsStore().appTheme == .system)
    }

    @Test("The app theme written is read back")
    func roundTrip() {
        let store = InMemorySettingsStore()
        store.setAppTheme(.dark)
        #expect(store.appTheme == .dark)
    }

    @Test("An unreadable stored app theme falls back to System")
    func unreadableFallsBack() {
        let store = InMemorySettingsStore()
        store.set("sepia", for: SettingKey(AppSettingKeys.theme.name, default: ""))
        #expect(store.appTheme == .system)
    }

    @Test("The app theme and the reader theme are stored apart")
    func independentOfReaderTheme() {
        let store = InMemorySettingsStore()
        store.setAppTheme(.light)
        store.setReaderPreferences(ReaderPreferences(theme: .dark))
        #expect(store.appTheme == .light)
        #expect(store.readerPreferences.theme == .dark)
    }

    @Test("The app theme lives in the settings namespace, so a reset clears it")
    func namespaced() {
        let store = InMemorySettingsStore()
        store.setAppTheme(.dark)
        store.removeAll()
        #expect(store.appTheme == .system)
    }
}
