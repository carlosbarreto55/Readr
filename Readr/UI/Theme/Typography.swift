import SwiftUI

/// The app's type scale.
///
/// Every entry is a `Font.TextStyle`, never a point size. Readr is a reading app:
/// a fixed size is a bug, not a style choice, and text must grow when the reader
/// asks it to.
public enum Typography {
    /// A screen's primary heading.
    public static let screenTitle: Font = .largeTitle.weight(.bold)
    /// A section heading within a screen.
    public static let sectionTitle: Font = .title3.weight(.semibold)
    /// The title on a series card.
    public static let cardTitle: Font = .subheadline.weight(.medium)
    /// Supporting text beneath a title.
    public static let caption: Font = .caption
    /// Body copy outside the reader. Reader body type is chosen by the reader.
    public static let body: Font = .body
}
