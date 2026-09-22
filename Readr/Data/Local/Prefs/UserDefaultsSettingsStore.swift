import Foundation

/// `SettingsStore` backed by `UserDefaults`.
///
/// The only place `UserDefaults` is named. Nothing above the data layer knows
/// that is where settings live.
///
/// `@unchecked Sendable` because `UserDefaults` is documented as thread-safe but
/// is not annotated `Sendable`. The unchecked part is that assurance, not a
/// suppression: this type adds no mutable state of its own.
public struct UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func value<Value: SettingValue>(for key: SettingKey<Value>) -> Value {
        // `object(forKey:)` rather than the typed accessors: those map a missing
        // key and a stored `false`/`0` onto the same result, which would make an
        // unset setting indistinguishable from one deliberately set to zero.
        guard let stored = defaults.object(forKey: key.name) as? Value else {
            return key.defaultValue
        }
        return stored
    }

    public func set<Value: SettingValue>(_ value: Value, for key: SettingKey<Value>) {
        defaults.set(value, forKey: key.name)
    }

    /// Removes only keys inside `SettingNamespace`.
    ///
    /// `dictionaryRepresentation()` is the merged view across the argument,
    /// application, global, and registration domains — hundreds of keys, almost
    /// none of them Readr's. Clearing the reader's settings must not also clear
    /// whatever UIKit, the image loader, or a future Spotlight bookkeeping key
    /// happens to be sharing the domain.
    public func removeAll() {
        for name in defaults.dictionaryRepresentation().keys
        where name.hasPrefix(SettingNamespace.prefix) {
            defaults.removeObject(forKey: name)
        }
    }
}
