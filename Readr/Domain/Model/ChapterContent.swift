import Foundation

/// The two shapes a chapter's content can take.
///
/// Exactly two cases, per `architecture.md` §4.2. A source declaring
/// `ContentType.novel` returns `.text`; manhwa and manga return `.pages`.
/// Adding a third case is an architecture change, not a feature.
public enum ChapterContent: Sendable, Hashable {
    /// Novel content, carried as HTML and rendered natively as attributed text.
    case text(html: String)
    /// Manhwa or manga content: page images in reading order.
    case pages(imageURLs: [URL])

    /// Whether this payload has the content shape promised by a route or source.
    public func matches(_ type: ContentType) -> Bool {
        switch (self, type) {
        case (.text, .novel), (.pages, .manhwa), (.pages, .manga): true
        default: false
        }
    }
}
