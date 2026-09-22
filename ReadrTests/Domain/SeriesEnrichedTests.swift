import Foundation
import Testing

@testable import Readr

@Suite("Series.enriched(with:)")
struct SeriesEnrichedTests {
    private let url = URL(string: "https://example.test/series/one")!
    private let coverURL = URL(string: "https://example.test/cover.jpg")!

    private func known(
        title: String = "Known Title",
        coverURL: URL? = nil,
        synopsis: String? = nil,
        author: String? = nil,
        artist: String? = nil,
        genres: [String] = [],
        status: SeriesStatus = .unknown
    ) -> Series {
        Series(
            sourceID: 42,
            url: url,
            title: title,
            coverURL: coverURL,
            synopsis: synopsis,
            author: author,
            artist: artist,
            genres: genres,
            status: status,
            contentType: .novel
        )
    }

    @Test("A populated field replaces what was known")
    func populatedFieldsReplace() {
        let merged = known(synopsis: "Old", author: "Old Author", status: .unknown)
            .enriched(
                with: known(
                    title: "New Title",
                    coverURL: coverURL,
                    synopsis: "New",
                    author: "New Author",
                    genres: ["Action"],
                    status: .ongoing))

        #expect(merged.title == "New Title")
        #expect(merged.coverURL == coverURL)
        #expect(merged.synopsis == "New")
        #expect(merged.author == "New Author")
        #expect(merged.genres == ["Action"])
        #expect(merged.status == .ongoing)
    }

    /// The requirement this whole function exists for. A detail page that omits a
    /// field must not blank the value a catalog listing supplied — the series
    /// still renders afterwards, just worse, so nothing reports it.
    @Test("A field the detail page omits keeps its previous value")
    func absentFieldsArePreserved() {
        let before = known(
            coverURL: coverURL,
            synopsis: "A synopsis the listing had",
            author: "Known Author",
            artist: "Known Artist",
            genres: ["Fantasy", "Drama"],
            status: .completed)

        let merged = before.enriched(with: known(title: "Refreshed"))

        #expect(merged.title == "Refreshed")
        #expect(merged.coverURL == coverURL)
        #expect(merged.synopsis == "A synopsis the listing had")
        #expect(merged.author == "Known Author")
        #expect(merged.artist == "Known Artist")
        #expect(merged.genres == ["Fantasy", "Drama"])
        #expect(merged.status == .completed)
    }

    @Test("An empty string is treated as absent, not as a value")
    func emptyStringsDoNotOverwrite() {
        let before = known(synopsis: "Kept", author: "Kept")
        let merged = before.enriched(with: known(title: "", synopsis: "", author: "   "))

        #expect(merged.title == "Known Title")
        #expect(merged.synopsis == "Kept")
        #expect(merged.author == "Kept")
    }

    @Test("An empty genre list is treated as absent")
    func emptyGenresDoNotOverwrite() {
        let merged = known(genres: ["Action"]).enriched(with: known(genres: []))
        #expect(merged.genres == ["Action"])
    }

    /// `.unknown` is what an unrecognized status degrades to, so it means "this
    /// page did not tell me" rather than "this series has no status".
    @Test("An unknown status does not overwrite a known one")
    func unknownStatusDoesNotOverwrite() {
        #expect(known(status: .ongoing).enriched(with: known(status: .unknown)).status == .ongoing)
        #expect(
            known(status: .ongoing).enriched(with: known(status: .completed)).status == .completed)
    }

    /// Identity is not a parameter of the merge, so a detail page that resolved
    /// to a different URL cannot quietly turn this into a different series.
    @Test("Identity comes from the known series and cannot be replaced")
    func identityIsPreserved() {
        let elsewhere = Series(
            sourceID: 99,
            url: URL(string: "https://elsewhere.test/other")!,
            title: "Different",
            contentType: .novel)

        let merged = known().enriched(with: elsewhere)

        #expect(merged.sourceID == 42)
        #expect(merged.url == url)
        #expect(merged.id == SeriesID(sourceID: 42, url: url))
    }

    @Test("Merging is idempotent")
    func mergeIsIdempotent() {
        let details = known(title: "Detailed", synopsis: "S", genres: ["G"], status: .ongoing)
        let once = known().enriched(with: details)
        #expect(once.enriched(with: details) == once)
        #expect(once.enriched(with: details).synopsis == once.synopsis)
    }
}
