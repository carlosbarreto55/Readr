import CoreGraphics

/// The app's spacing scale.
///
/// One scale, used everywhere. A literal inset in a view is a bug waiting to
/// disagree with the view next to it.
public enum Spacing {
    public static let xxSmall: CGFloat = 2
    public static let xSmall: CGFloat = 4
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 16
    public static let xLarge: CGFloat = 24
    public static let xxLarge: CGFloat = 32

    /// The inset used along the leading and trailing edges of a screen.
    public static let screenMargin: CGFloat = large
}
