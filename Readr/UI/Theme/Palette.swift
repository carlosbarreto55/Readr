import SwiftUI

/// The app's semantic colors.
///
/// Semantic rather than literal, so light and dark both follow from the system
/// without a second palette to keep in sync.
public enum Palette {
    /// The app's tint, from the asset catalog's `AccentColor`.
    public static let accent = Color.accentColor
    /// The surface a screen sits on.
    public static let background = Color(.systemBackground)
    /// A card or row raised above the background.
    public static let surface = Color(.secondarySystemBackground)
    /// Primary text.
    public static let label = Color(.label)
    /// Supporting text.
    public static let secondaryLabel = Color(.secondaryLabel)
    /// A hairline divider.
    public static let separator = Color(.separator)
    /// Stands in for cover art that has not loaded or cannot be fetched.
    public static let coverPlaceholder = Color(.tertiarySystemFill)
}
