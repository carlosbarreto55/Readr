import Foundation

/// The two shapes a chapter's content can take.
///
/// Exactly two cases, per `architecture.md` §4.2. A source declaring
/// `ContentType.novel` returns `.text`; one declaring `.manhwa` returns `.pages`.
/// Adding a third case is an architecture change, not a feature.
public enum ChapterContent: Sendable, Hashable {
    /// Novel content, carried as HTML and rendered natively as attributed text.
    case text(html: String)
    /// Manhwa content: page images in reading order.
    case pages(imageURLs: [URL])

    /// The content type this payload satisfies, for checking a payload against
    /// the type its route promised.
    public var contentType: ContentType {
        switch self {
        case .text: .novel
        case .pages: .manhwa
        }
    }
}
