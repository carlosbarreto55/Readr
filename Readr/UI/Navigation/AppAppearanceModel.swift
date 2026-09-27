import Observation
import SwiftUI

/// The app theme as live state, so the shell re-renders the moment it changes.
///
/// `SettingsStore` cannot notify anyone, so this model is the one writer of the
/// app theme and the one thing `RootTabView` observes. The store stays the
/// source of truth across launches.
@Observable
@MainActor
final class AppAppearanceModel {
    private let settings: any SettingsStore

    private(set) var theme: AppTheme

    init(settings: any SettingsStore) {
        self.settings = settings
        theme = settings.appTheme
    }

    func set(_ theme: AppTheme) {
        self.theme = theme
        settings.setAppTheme(theme)
    }

    /// Re-reads the store after something cleared it behind this model's back —
    /// Reset Settings.
    func reload() {
        theme = settings.appTheme
    }

    /// The scheme the whole app renders in, or `nil` to follow the system.
    var colorScheme: ColorScheme? {
        switch theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension EnvironmentValues {
    /// Installed by `RootTabView`; `nil` outside the app shell, such as in
    /// previews.
    @Entry var appAppearance: AppAppearanceModel?
}
