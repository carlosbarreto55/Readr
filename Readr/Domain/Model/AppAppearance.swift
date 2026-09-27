/// How the whole app looks, apart from the Reader, which has its own
/// `ReaderTheme`. The two are independent: neither ever writes the other.
public enum AppTheme: String, Sendable, Hashable, CaseIterable, Identifiable {
    /// Follows the system appearance.
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// The settings keys app-wide appearance is stored under.
public enum AppSettingKeys {
    public static let theme = RawSettingKey("readr.app.theme", default: AppTheme.system)
}

extension SettingsStore {
    /// The stored app theme, or `.system` where nothing is stored.
    public var appTheme: AppTheme {
        value(for: AppSettingKeys.theme)
    }

    public func setAppTheme(_ theme: AppTheme) {
        set(theme, for: AppSettingKeys.theme)
    }
}
