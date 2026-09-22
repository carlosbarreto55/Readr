import Foundation
import Testing

@testable import Readr

@Suite("ChapterContent")
struct ChapterContentTests {

    @Test("Text content reports the novel content type")
    func textIsNovel() {
        #expect(ChapterContent.text(html: "<p>Chapter one.</p>").contentType == .novel)
    }

    @Test("Page content reports the manhwa content type")
    func pagesAreManhwa() {
        let pages = ChapterContent.pages(imageURLs: [
            URL(string: "https://example.test/p/1.jpg")!,
            URL(string: "https://example.test/p/2.jpg")!
        ])
        #expect(pages.contentType == .manhwa)
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
        #expect(ChapterContent.pages(imageURLs: []).contentType == .manhwa)
    }
}
