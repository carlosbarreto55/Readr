import Foundation
import Testing

@testable import Readr

@Suite("ChapterContent")
struct ChapterContentTests {

    @Test("Text content reports the novel content type")
    func textIsNovel() {
        #expect(ChapterContent.text(html: "<p>Chapter one.</p>").matches(.novel))
        #expect(!ChapterContent.text(html: "<p>Chapter one.</p>").matches(.manga))
        #expect(!ChapterContent.text(html: "<p>Chapter one.</p>").matches(.comic))
    }

    @Test("Page content reports every image content type")
    func pagesAreManhwa() {
        let pages = ChapterContent.pages(imageURLs: [
            URL(string: "https://example.test/p/1.jpg")!,
            URL(string: "https://example.test/p/2.jpg")!
        ])
        #expect(pages.matches(.manhwa))
        #expect(pages.matches(.manga))
        #expect(pages.matches(.comic))
        #expect(!pages.matches(.novel))
    }

    @Test("Page order is the reading order it was given")
    func pagesPreserveOrder() {
        let urls = (1...3).map { URL(string: "https://example.test/p/\($0).jpg")! }
        guard case .pages(let stored) = ChapterContent.pages(imageURLs: urls) else {
            Issue.record("Expected .pages")
            return
        }
        #expect(stored == urls)
    }

    @Test("An empty page list is representable without becoming text")
    func emptyPagesStayPages() {
        #expect(ChapterContent.pages(imageURLs: []).matches(.manga))
    }
}
