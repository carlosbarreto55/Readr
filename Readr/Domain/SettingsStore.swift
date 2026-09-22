/// A value that may be stored as a setting.
///
/// A closed set on purpose. Settings hold the reader's own choices — a handful of
/// flags, numbers, and names — never library state and never chapter content.
public protocol SettingValue: Sendable, Equatable {}

extension Bool: SettingValue {}
extension Int: SettingValue {}
extension Double: SettingValue {}
extension String: SettingValue {}

/// The namespace every setting name carries.
///
/// Not decoration. `UserDefaults` is a shared bag — the app's own domain also
/// holds keys written by the system frameworks, by the image loader, and by
/// anything else linked in. Without a namespace, "clear every setting" has no
/// definition narrow enough to be safe to implement.
public enum SettingNamespace {
    public static let prefix = "readr."
}

/// A setting, named and with the value it takes before anyone has set it.
///
/// The default is part of the key rather than supplied at each call site, so a
/// setting cannot read back as one default in one place and another elsewhere.
///
/// Named `SettingKey` rather than `PreferenceKey` because SwiftUI already defines
/// a `PreferenceKey` protocol, and a screen should never have to disambiguate.
public struct SettingKey<Value: SettingValue>: Sendable {
    public let name: String
    public let defaultValue: Value

    /// - Precondition: `name` begins with `SettingNamespace.prefix`. A key
    ///   outside the namespace is one `removeAll()` would not clear, so it would
    ///   read back as a stale value after the reader reset their settings.
    public init(_ name: String, default defaultValue: Value) {
        precondition(
            name.hasPrefix(SettingNamespace.prefix),
            "Setting name '\(name)' must begin with '\(SettingNamespace.prefix)'. "
                + "Settings outside the namespace are not cleared by removeAll()."
        )
        self.name = name
        self.defaultValue = defaultValue
    }
}

/// A setting whose values are named cases, stored by raw name.
///
/// Separate from `SettingKey` because the value type is not itself a
/// `SettingValue` — it is written and read as its raw `String`.
public struct RawSettingKey<Value>: Sendable
where Value: RawRepresentable & Sendable, Value.RawValue == String {
    public let name: String
    public let defaultValue: Value

    /// - Precondition: `name` begins with `SettingNamespace.prefix`, for the
    ///   reason `SettingKey.init` gives.
    public init(_ name: String, default defaultValue: Value) {
        precondition(
            name.hasPrefix(SettingNamespace.prefix),
            "Setting name '\(name)' must begin with '\(SettingNamespace.prefix)'. "
                + "Settings outside the namespace are not cleared by removeAll()."
        )
        self.name = name
        self.defaultValue = defaultValue
    }
}

/// Reads and writes the reader's settings.
///
/// Plain Swift. The storage mechanism is named only by the implementation, which
/// is what keeps `UserDefaults` out of the domain and out of presentation.
public protocol SettingsStore: Sendable {
    /// The stored value, or the key's default if nothing is stored or if what is
    /// stored cannot be read back as `Value`.
    func value<Value: SettingValue>(for key: SettingKey<Value>) -> Value

    func set<Value: SettingValue>(_ value: Value, for key: SettingKey<Value>)

    /// Clears every setting in `SettingNamespace`, and nothing else.
    ///
    /// Library and chapter state are unaffected — nothing of either is stored
    /// here. Neither is anything the app did not write as a setting: the store
    /// shares a `UserDefaults` domain with the system frameworks, so the bound
    /// is the namespace rather than the domain.
    func removeAll()
}

extension SettingsStore {
    /// Reads a setting whose values are named cases.
    ///
    /// A stored name matching no case — because the app changed, or because the
    /// value was written by a later version — resolves to the key's default
    /// rather than failing.
    public func value<Value>(for key: RawSettingKey<Value>) -> Value {
        let stored = value(for: SettingKey(key.name, default: key.defaultValue.rawValue))
        return Value(rawValue: stored) ?? key.defaultValue
    }

    public func set<Value>(_ value: Value, for key: RawSettingKey<Value>) {
        set(value.rawValue, for: SettingKey(key.name, default: key.defaultValue.rawValue))
    }
}
