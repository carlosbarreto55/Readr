import Foundation

/// `SettingsStore` that keeps values for the lifetime of the process.
///
/// For previews and tests, so neither touches the real `UserDefaults` domain and
/// leaves settings behind for the next run.
public final class InMemorySettingsStore: SettingsStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: any Sendable] = [:]

    public init() {}

    public func value<Value: SettingValue>(for key: SettingKey<Value>) -> Value {
        lock.withLock { storage[key.name] as? Value ?? key.defaultValue }
    }

    public func set<Value: SettingValue>(_ value: Value, for key: SettingKey<Value>) {
        lock.withLock { storage[key.name] = value }
    }

    public func removeAll() {
        lock.withLock { storage.removeAll() }
    }
}
