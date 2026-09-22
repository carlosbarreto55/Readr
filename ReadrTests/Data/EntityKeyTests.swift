import Foundation
import Testing

@testable import Readr

/// Both keys are persisted format. The database key decides which rows are the
/// same series; the path key names directories that hold downloaded files. These
/// expectations are hardcoded and are never updated to match changed output — a
/// path key that drifts strands every file already on disk.
@Suite("EntityKey")
struct EntityKeyTests {
    private let seriesURL = URL(string: "https://example.test/series/one")!
    private let chapterURL = URL(string: "https://example.test/series/one/ch/1")!

    @Test("The database key carries the URL in full")
    func identityKey() {
        #expect(
            EntityKey.identity(sourceID: 42, url: seriesURL)
                == "42|https://example.test/series/one"
        )
    }

    @Test("The database key is derived the same way from a stored URL string")
    func identityKeyFromString() {
        #expect(
            EntityKey.identity(sourceID: 42, urlString: seriesURL.absoluteString)
                == EntityKey.identity(sourceID: 42, url: seriesURL)
        )
    }

    @Test("Both halves of the identity affect the database key")
    func identityKeyUsesBothComponents() {
        #expect(
            EntityKey.identity(sourceID: 42, url: seriesURL)
                != EntityKey.identity(sourceID: 43, url: seriesURL)
        )
        #expect(
            EntityKey.identity(sourceID: 42, url: seriesURL)
                != EntityKey.identity(sourceID: 42, url: chapterURL)
        )
    }

    @Test("Path keys are their recorded values")
    func pathKey() {
        #expect(EntityKey.path(for: seriesURL) == "d6d66af9aa041cb9")
        #expect(EntityKey.path(for: chapterURL) == "847f92a09d63f901")
    }

    @Test("A path key is always sixteen filesystem-safe characters")
    func pathKeyShape() {
        let safe = Set("0123456789abcdef")
        for path in [
            "https://example.test/a", "https://example.test/a?q=1&r=2#frag", "https://例.test/日本"
        ] {
            let key = EntityKey.path(
                for: URL(
                    string: path.addingPercentEncoding(
                        withAllowedCharacters: .urlFragmentAllowed)!)!)
            #expect(key.count == 16)
            #expect(key.allSatisfy(safe.contains))
        }
    }

    @Test("Different URLs get different path keys")
    func pathKeysDiffer() {
        #expect(EntityKey.path(for: seriesURL) != EntityKey.path(for: chapterURL))
    }
}
