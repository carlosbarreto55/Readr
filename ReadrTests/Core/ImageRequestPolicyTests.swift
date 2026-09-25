import Foundation
import Testing

@testable import Readr

@Suite("Image request policy")
struct ImageRequestPolicyTests {
    @Test("MangaPill covers and pages receive a referer; other hosts do not")
    func scopedReferer() {
        for path in ["/file/mangapill/i/1.jpeg", "/file/mangap/chapter/1.jpeg"] {
            let request = URLRequest(
                url: URL(string: "https://cdn.readdetectiveconan.com\(path)")!)
            #expect(
                ImageRequestPolicy.prepared(request).value(forHTTPHeaderField: "Referer")
                    == "https://mangapill.com/")
        }
        let unrelated = URLRequest(url: URL(string: "https://cdn.example.test/1.jpeg")!)
        #expect(ImageRequestPolicy.prepared(unrelated).value(forHTTPHeaderField: "Referer") == nil)
    }
}
