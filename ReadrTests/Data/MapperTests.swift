import Foundation
import Testing

@testable import Readr

@Suite("Entity mappers")
struct MapperTests {
    private let seriesURL = URL(string: "https://example.test/series/one")!
    private let chapterURL = URL(string: "https://example.test/series/one/ch/1")!

    private func series(title: String = "A Title") -> Series {
        Series(
            sourceID: 42,
            url: seriesURL,
            title: title,
            coverURL: URL(string: "https://example.test/cover.jpg"),
            synopsis: "A synopsis.",
            author: "An Author",
            artist: "An Artist",
            genres: ["Fantasy", "Action"],
            status: .ongoing,
            contentType: .manhwa
        )
    }

    @Test("A series survives a round trip with every field intact")
    func seriesRoundTrip() {
        let original = series()
        let restored = SeriesMapper.toDomain(SeriesMapper.makeEntity(from: original))
        #expect(restored?.sourceID == original.sourceID)
        #expect(restored?.url == original.url)
        #expect(restored?.title == original.title)
        #expect(restored?.coverURL == original.coverURL)
        #expect(restored?.synopsis == original.synopsis)
        #expect(restored?.author == original.author)
        #expect(restored?.artist == original.artist)
        #expect(restored?.genres == original.genres)
        #expect(restored?.status == original.status)
        #expect(restored?.contentType == original.contentType)
        #expect(restored?.id == original.id)
    }

    @Test("A series with only its required fields survives a round trip")
    func sparseSeriesRoundTrip() {
        let sparse = Series(sourceID: 1, url: seriesURL, title: "T", contentType: .novel)
        let restored = SeriesMapper.toDomain(SeriesMapper.makeEntity(from: sparse))
        #expect(restored == sparse)
        #expect(restored?.coverURL == nil)
        #expect(restored?.genres.isEmpty == true)
        #expect(restored?.status == .unknown)
    }

    @Test("An entity is stored under its derived identity key")
    func entityCarriesItsKey() {
        let entity = SeriesMapper.makeEntity(from: series())
        #expect(entity.key == EntityKey.identity(sourceID: 42, url: seriesURL))
    }

    /// A status the app no longer recognizes degrades rather than discarding the
    /// row — losing a status is recoverable, losing a saved series is not.
    @Test("An unrecognized stored status degrades to unknown")
    func unknownStatusDegrades() {
        let entity = SeriesMapper.makeEntity(from: series())
        entity.statusRaw = "somethingALaterVersionWrote"
        #expect(SeriesMapper.toDomain(entity)?.status == .unknown)
    }

    @Test("An unreadable stored row maps to nothing rather than to a broken value")
    func corruptRowMapsToNil() {
        let entity = SeriesMapper.makeEntity(from: series())
        entity.contentTypeRaw = "notAContentType"
        #expect(SeriesMapper.toDomain(entity) == nil)
    }

    @Test("Applying metadata leaves the reader's own state alone")
    func applyPreservesReaderState() {
        let entity = SeriesMapper.makeEntity(from: series(title: "Original"))
        let added = entity.dateAdded
        entity.lastReadAt = Date(timeIntervalSince1970: 1_000)

        SeriesMapper.apply(series(title: "Retitled"), to: entity)

        #expect(entity.title == "Retitled")
        #expect(entity.dateAdded == added)
        #expect(entity.lastReadAt == Date(timeIntervalSince1970: 1_000))
        #expect(entity.key == EntityKey.identity(sourceID: 42, url: seriesURL))
    }

    @Test("A chapter survives a round trip with every field intact")
    func chapterRoundTrip() {
        let original = Chapter(
            sourceID: 42,
            seriesURL: seriesURL,
            url: chapterURL,
            name: "Chapter 1",
            number: 1,
            dateUploaded: Date(timeIntervalSince1970: 2_000),
            scanlator: "A Group"
        )
        let restored = ChapterMapper.toDomain(ChapterMapper.makeEntity(from: original))
        #expect(restored?.id == original.id)
        #expect(restored?.seriesURL == original.seriesURL)
        #expect(restored?.name == original.name)
        #expect(restored?.number == original.number)
        #expect(restored?.dateUploaded == original.dateUploaded)
        #expect(restored?.scanlator == original.scanlator)
    }

    /// This is what lets a chapter-list refresh update metadata without throwing
    /// away where the reader had got to.
    @Test("Applying chapter metadata leaves read state alone")
    func chapterApplyPreservesProgress() {
        let entity = ChapterMapper.makeEntity(
            from: Chapter(
                sourceID: 42, seriesURL: seriesURL, url: chapterURL, name: "Ch. 1", number: 1))
        entity.isRead = true
        entity.readingPosition = 0.5

        ChapterMapper.apply(
            Chapter(sourceID: 42, seriesURL: seriesURL, url: chapterURL, name: "Ch. 01", number: 2),
            to: entity)

        #expect(entity.name == "Ch. 01")
        #expect(entity.number == 2)
        #expect(entity.isRead)
        #expect(entity.readingPosition == 0.5)
    }
}
