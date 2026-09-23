import SwiftUI

/// The Reader's surface and text colors per reader theme.
///
/// `system` follows the app's semantic palette, so it tracks light and dark. The
/// fixed themes pin a color scheme too, so chrome and system overlays drawn over
/// the page stay legible against it.
public enum ReaderColors {

    public static func background(_ theme: ReaderTheme) -> Color {
        switch theme {
        case .system: Palette.background
        case .light: Color(white: 1)
        case .sepia: Color(red: 0.97, green: 0.93, blue: 0.84)
        case .dark: Color(white: 0.07)
        }
    }

    public static func text(_ theme: ReaderTheme) -> Color {
        switch theme {
        case .system: Palette.label
        case .light: Color(white: 0.1)
        case .sepia: Color(red: 0.33, green: 0.24, blue: 0.15)
        case .dark: Color(white: 0.86)
        }
    }

    public static func secondaryText(_ theme: ReaderTheme) -> Color {
        text(theme).opacity(0.6)
    }

    /// The scheme the Reader's chrome renders in, or `nil` to follow the system.
    public static func colorScheme(_ theme: ReaderTheme) -> ColorScheme? {
        switch theme {
        case .system: nil
        case .light, .sepia: .light
        case .dark: .dark
        }
    }
}
