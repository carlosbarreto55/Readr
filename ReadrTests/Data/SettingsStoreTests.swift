import Foundation
import Testing

@testable import Readr

@Suite("SettingsStore")
struct SettingsStoreTests {

    private enum SortOrder: String, Sendable {
        case title
        case dateAdded
        case lastRead
    }

    private let flag = SettingKey("readr.test.flag", default: true)
    private let count = SettingKey("readr.test.count", default: 7)
    private let name = SettingKey("readr.test.name", default: "unset")
    private let sort = RawSettingKey("readr.test.sort", default: SortOrder.title)

    /// A `UserDefaults` of its own, so a test run leaves nothing behind for the
    /// next one and never touches the app's real settings.
    private func makeStore() -> UserDefaultsSettingsStore {
        let suite = "readr.tests.\(UUID().uuidString)"
        return UserDefaultsSettingsStore(defaults: UserDefaults(suiteName: suite)!)
    }

    @Test("An unset setting reads as its declared default")
    func unsetReturnsDefault() {
        let store = makeStore()
        #expect(store.value(for: flag) == true)
        #expect(store.value(for: count) == 7)
        #expect(store.value(for: name) == "unset")
        #expect(store.value(for: sort) == .title)
    }

    @Test("A written setting reads back")
    func writtenValueReadsBack() {
        let store = makeStore()
        store.set(false, for: flag)
        store.set(0, for: count)
        store.set("chosen", for: name)
        store.set(SortOrder.lastRead, for: sort)

        #expect(store.value(for: flag) == false)
        #expect(store.value(for: count) == 0)
        #expect(store.value(for: name) == "chosen")
        #expect(store.value(for: sort) == .lastRead)
    }

    /// The reason the implementation reads `object(forKey:)` rather than
    /// `bool(forKey:)`: the typed accessors map "never set" and "set to false"
    /// onto the same answer, which would make a default of `true` unsettable.
    @Test("A setting deliberately set to a falsy value is not mistaken for unset")
    func falsyValueIsDistinguishableFromUnset() {
        let store = makeStore()
        store.set(false, for: flag)
        #expect(store.value(for: flag) == false)

        store.set(0, for: count)
        #expect(store.value(for: count) == 0)
    }

    @Test("A stored value of the wrong type resolves to the default")
    func wrongTypeResolvesToDefault() {
        let suite = "readr.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set("not a number", forKey: count.name)

        #expect(UserDefaultsSettingsStore(defaults: defaults).value(for: count) == 7)
    }

    @Test("A stored name matching no case resolves to the default")
    func unrecognizedRawValueResolvesToDefault() {
        let store = makeStore()
        store.set("anOrderALaterVersionAdded", for: SettingKey(sort.name, default: ""))
        #expect(store.value(for: sort) == .title)
    }

    @Test("Clearing returns every setting to its default")
    func removeAllRestoresDefaults() {
        let store = makeStore()
        store.set(false, for: flag)
        store.set("chosen", for: name)

        store.removeAll()

        #expect(store.value(for: flag) == true)
        #expect(store.value(for: name) == "unset")
    }

    @Test("Settings survive the store being rebuilt over the same domain")
    func settingsSurviveRelaunch() {
        let suite = "readr.tests.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }

        // A relaunch is a new store instance reading the same domain, which is
        // the only part of relaunch this layer can observe.
        UserDefaultsSettingsStore(defaults: UserDefaults(suiteName: suite)!)
            .set("chosen", for: name)

        let afterRelaunch = UserDefaultsSettingsStore(defaults: UserDefaults(suiteName: suite)!)
        #expect(afterRelaunch.value(for: name) == "chosen")
    }

    /// The bound on `removeAll()`. The store shares its domain with the system
    /// frameworks and with anything else linked in, so clearing the reader's
    /// settings must not clear theirs.
    @Test("Clearing leaves keys outside the settings namespace alone")
    func removeAllIsScopedToTheNamespace() {
        let suite = "readr.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { UserDefaults().removePersistentDomain(forName: suite) }

        defaults.set("not ours", forKey: "SomeFrameworkWroteThis")
        let store = UserDefaultsSettingsStore(defaults: defaults)
        store.set(false, for: flag)

        store.removeAll()

        #expect(store.value(for: flag) == true)
        #expect(defaults.string(forKey: "SomeFrameworkWroteThis") == "not ours")
    }

    @Test("The in-memory store behaves the same way")
    func inMemoryStoreMatches() {
        let store = InMemorySettingsStore()
        #expect(store.value(for: flag) == true)
        store.set(false, for: flag)
        #expect(store.value(for: flag) == false)
        store.removeAll()
        #expect(store.value(for: flag) == true)
    }
}
