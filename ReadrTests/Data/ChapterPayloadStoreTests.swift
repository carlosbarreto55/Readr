import Foundation
import Testing

@testable import Readr

@Suite("Chapter payload store")
struct ChapterPayloadStoreTests {
    private let seriesURL = URL(string: "https://example.test/series/one")!
    private var chapter: ChapterID {
        ChapterID(sourceID: 42, url: URL(string: "https://example.test/series/one/c1")!)
    }

    private func makeStore() throws -> ChapterPayloadStore {
        try ChapterPayloadStore(
            root: FileManager.default.temporaryDirectory
                .appending(path: "readr-store-\(UUID().uuidString)/Downloads"))
    }

    @Test("Payloads live at <sourceID>/<seriesKey>/<chapterKey> under Downloads")
    func layout() throws {
        let store = try makeStore()
        let directory = store.directory(for: chapter, seriesURL: seriesURL)
        let expected = store.root
            .appending(path: "42")
            .appending(path: EntityKey.path(for: seriesURL))
            .appending(path: EntityKey.path(for: chapter.url))
        // Components, not URLs: the store marks directories with a trailing slash.
        #expect(
            directory.standardizedFileURL.pathComponents
                == expected.standardizedFileURL.pathComponents)
        #expect(
            Array(directory.pathComponents.suffix(3)) == [
                "42", EntityKey.path(for: seriesURL), EntityKey.path(for: chapter.url)
            ])
    }

    @Test("The Downloads directory is excluded from backup")
    func excludedFromBackup() throws {
        let store = try makeStore()
        let values = try store.root.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test("Stored text reads back once committed, and not before")
    func textRoundTrip() throws {
        let store = try makeStore()
        let staging = try store.beginWrite(for: chapter, seriesURL: seriesURL)
        let name = try store.writeText("<p>Stored.</p>", into: staging)
        #expect(store.content(for: chapter, seriesURL: seriesURL) == nil)

        let bytes = try store.commit(
            .init(contentType: "novel", files: [name]), staging: staging, for: chapter,
            seriesURL: seriesURL)

        #expect(store.content(for: chapter, seriesURL: seriesURL) == .text(html: "<p>Stored.</p>"))
        #expect(bytes > 0)
        #expect(store.totalSize() == bytes)
    }

    @Test("Stored pages read back as local file URLs in order")
    func pagesAreLocal() throws {
        let store = try makeStore()
        let staging = try store.beginWrite(for: chapter, seriesURL: seriesURL)
        let names = try (0..<3).map { index in
            try store.writePage(
                Data("page \(index)".utf8), index: index,
                sourceURL: URL(string: "https://cdn.test/\(index).webp")!, into: staging)
        }
        try store.commit(
            .init(contentType: "manhwa", files: names), staging: staging, for: chapter,
            seriesURL: seriesURL)

        guard case .pages(let urls) = store.content(for: chapter, seriesURL: seriesURL) else {
            Issue.record("Expected pages")
            return
        }
        #expect(urls.count == 3)
        #expect(urls.allSatisfy { $0.isFileURL })
        #expect(
            urls.map(\.lastPathComponent) == ["page-0001.webp", "page-0002.webp", "page-0003.webp"])
        #expect(try Data(contentsOf: urls[1]) == Data("page 1".utf8))
    }

    @Test(
        "Manga and comic page payloads keep their type and reopen as local files",
        arguments: ["manga", "comic"])
    func imagePagesAreLocal(contentType: String) throws {
        let store = try makeStore()
        let staging = try store.beginWrite(for: chapter, seriesURL: seriesURL)
        let name = try store.writePage(
            Data(contentType.utf8), index: 0,
            sourceURL: URL(string: "https://cdn.test/1.jpeg")!, into: staging)
        try store.commit(
            .init(contentType: contentType, files: [name]), staging: staging, for: chapter,
            seriesURL: seriesURL)
        guard case .pages(let urls) = store.content(for: chapter, seriesURL: seriesURL) else {
            Issue.record("Expected \(contentType) pages")
            return
        }
        #expect(urls.count == 1)
        #expect(urls[0].isFileURL)
        #expect(try Data(contentsOf: urls[0]) == Data(contentType.utf8))
    }

    @Test("A chapter missing any file it names is not reported as stored")
    func missingAssetIsNotStored() throws {
        let store = try makeStore()
        let staging = try store.beginWrite(for: chapter, seriesURL: seriesURL)
        let name = try store.writePage(
            Data("p".utf8), index: 0, sourceURL: URL(string: "https://cdn.test/0.jpg")!,
            into: staging)
        try store.commit(
            .init(contentType: "manhwa", files: [name, "page-0002.jpg"]), staging: staging,
            for: chapter, seriesURL: seriesURL)

        #expect(store.content(for: chapter, seriesURL: seriesURL) == nil)
    }

    @Test("Discarding a partial write leaves nothing behind")
    func discardPartial() throws {
        let store = try makeStore()
        let staging = try store.beginWrite(for: chapter, seriesURL: seriesURL)
        _ = try store.writeText("half", into: staging)

        store.discardPartial(for: chapter, seriesURL: seriesURL)

        #expect(!FileManager.default.fileExists(atPath: staging.path(percentEncoded: false)))
        #expect(store.totalSize() == 0)
    }

    @Test("Deleting a series or everything frees the space")
    func deletion() throws {
        let store = try makeStore()
        for slug in ["c1", "c2"] {
            let id = ChapterID(sourceID: 42, url: seriesURL.appending(path: slug))
            let staging = try store.beginWrite(for: id, seriesURL: seriesURL)
            let name = try store.writeText(slug, into: staging)
            try store.commit(
                .init(contentType: "novel", files: [name]), staging: staging, for: id,
                seriesURL: seriesURL)
        }
        #expect(store.totalSize() > 0)

        store.deleteSeries(sourceID: 42, seriesURL: seriesURL)
        #expect(store.totalSize() == 0)

        let staging = try store.beginWrite(for: chapter, seriesURL: seriesURL)
        let name = try store.writeText("again", into: staging)
        try store.commit(
            .init(contentType: "novel", files: [name]), staging: staging, for: chapter,
            seriesURL: seriesURL)
        store.deleteAll()
        #expect(store.totalSize() == 0)
        #expect(FileManager.default.fileExists(atPath: store.root.path(percentEncoded: false)))
    }
}
