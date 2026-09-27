import Foundation

/// How a content type is named on screen.
///
/// Exhaustive switches rather than chained ternaries, so a new content type
/// fails to compile here instead of quietly borrowing another type's label.
extension ContentType {
    /// One series of this type: "Novel", "Comic".
    var title: String {
        switch self {
        case .novel: "Novel"
        case .manhwa: "Manhwa"
        case .manga: "Manga"
        case .comic: "Comic"
        }
    }

    /// What one installment is called: a comic has issues, everything else chapters.
    var unitTitle: String {
        switch self {
        case .novel, .manhwa, .manga: "Chapter"
        case .comic: "Issue"
        }
    }

    /// `unitTitle`, plural.
    var pluralUnitTitle: String { unitTitle + "s" }

    /// Series of this type as a group: "Novels", "Comics".
    var pluralTitle: String {
        switch self {
        case .novel: "Novels"
        case .manhwa: "Manhwa"
        case .manga: "Manga"
        case .comic: "Comics"
        }
    }
}
