import Foundation

/// Downloaded chapter payloads on disk.
///
/// Layout, per `architecture.md` §6.3:
///
///     Application Support/Readr/Downloads/<sourceID>/<seriesKey>/<chapterKey>/
///         manifest.json
///         chapter.html            (novel)
///         page-0001.jpg …         (manhwa)
///
/// Writes go to a sibling `<chapterKey>.partial` directory and are renamed into
/// place only after the manifest is written, so a chapter directory either holds
/// a complete payload or does not exist. A read succeeds only when the manifest
/// and every file it names are present — a chapter with a missing asset is never
/// reported as stored.
///
/// Synchronous file I/O, so it is only ever called from the download repository's
/// actor, never from the main actor (invariant 7).
struct ChapterPayloadStore: Sendable {

    /// What a stored chapter holds, in reading order.
    struct Manifest: Codable, Equatable {
        let contentType: String
        let files: [String]
    }

    /// The `Downloads` directory itself.
    let root: URL

    private static let manifestName = "manifest.json"
    private static let textName = "chapter.html"

    /// The store the app runs with, under Application Support.
    static func live() throws -> ChapterPayloadStore {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
            create: true)
        return try ChapterPayloadStore(root: support.appending(path: "Readr/Downloads"))
    }

    /// - Throws: if the directory cannot be created or marked.
    init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        // Re-applied on every open: the flag is lost if the directory is ever
        // recreated, and re-downloadable content must never cost iCloud quota.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var marked = root
        try marked.setResourceValues(values)
    }

    // MARK: - Locations

    func directory(for chapter: ChapterID, seriesURL: URL) -> URL {
        seriesDirectory(sourceID: chapter.sourceID, seriesURL: seriesURL)
            .appending(path: EntityKey.path(for: chapter.url), directoryHint: .isDirectory)
    }

    func seriesDirectory(sourceID: Int64, seriesURL: URL) -> URL {
        root
            .appending(path: String(sourceID), directoryHint: .isDirectory)
            .appending(path: EntityKey.path(for: seriesURL), directoryHint: .isDirectory)
    }

    private func stagingDirectory(for chapter: ChapterID, seriesURL: URL) -> URL {
        let final = directory(for: chapter, seriesURL: seriesURL)
        return final.deletingLastPathComponent()
            .appending(path: final.lastPathComponent + ".partial", directoryHint: .isDirectory)
    }

    // MARK: - Writing

    /// A fresh, empty staging directory for a chapter about to be written.
    func beginWrite(for chapter: ChapterID, seriesURL: URL) throws -> URL {
        let staging = stagingDirectory(for: chapter, seriesURL: seriesURL)
        try? FileManager.default.removeItem(at: staging)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        return staging
    }

    func writeText(_ html: String, into staging: URL) throws -> String {
        try Data(html.utf8).write(to: staging.appending(path: Self.textName), options: .atomic)
        return Self.textName
    }

    /// - Returns: the stored file name.
    func writePage(_ data: Data, index: Int, sourceURL: URL, into staging: URL) throws -> String {
        let name = Self.pageName(index: index, sourceURL: sourceURL)
        try data.write(to: staging.appending(path: name), options: .atomic)
        return name
    }

    /// Writes the manifest and moves the staged chapter into place.
    ///
    /// - Returns: the stored chapter's size in bytes.
    @discardableResult
    func commit(
        _ manifest: Manifest, staging: URL, for chapter: ChapterID, seriesURL: URL
    ) throws -> Int64 {
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: staging.appending(path: Self.manifestName), options: .atomic)

        let final = directory(for: chapter, seriesURL: seriesURL)
        try? FileManager.default.removeItem(at: final)
        try FileManager.default.moveItem(at: staging, to: final)
        return Self.size(of: final)
    }

    /// Deletes whatever a failed or cancelled download left staged.
    func discardPartial(for chapter: ChapterID, seriesURL: URL) {
        try? FileManager.default.removeItem(
            at: stagingDirectory(for: chapter, seriesURL: seriesURL))
    }

    // MARK: - Reading

    /// The stored content, or `nil` unless every file the manifest names exists.
    func content(for chapter: ChapterID, seriesURL: URL) -> ChapterContent? {
        let directory = directory(for: chapter, seriesURL: seriesURL)
        guard
            let data = try? Data(contentsOf: directory.appending(path: Self.manifestName)),
            let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
            let type = ContentType(rawValue: manifest.contentType),
            !manifest.files.isEmpty
        else {
            return nil
        }

        let files = manifest.files.map { directory.appending(path: $0) }
        guard
            files.allSatisfy({
                FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
            })
        else {
            return nil
        }

        switch type {
        case .novel:
            guard let html = try? String(contentsOf: files[0], encoding: .utf8) else {
                return nil
            }
            return .text(html: html)
        case .manhwa, .manga:
            return .pages(imageURLs: files)
        }
    }

    // MARK: - Deleting

    func delete(_ chapter: ChapterID, seriesURL: URL) {
        try? FileManager.default.removeItem(at: directory(for: chapter, seriesURL: seriesURL))
        discardPartial(for: chapter, seriesURL: seriesURL)
    }

    func deleteSeries(sourceID: Int64, seriesURL: URL) {
        try? FileManager.default.removeItem(
            at: seriesDirectory(sourceID: sourceID, seriesURL: seriesURL))
    }

    /// Empties the downloads directory, keeping it and its backup exclusion.
    func deleteAll() {
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil)) ?? []
        for item in contents {
            try? FileManager.default.removeItem(at: item)
        }
    }

    // MARK: - Accounting

    /// Bytes stored under the downloads directory.
    func totalSize() -> Int64 {
        Self.size(of: root)
    }

    private static func size(of directory: URL) -> Int64 {
        guard
            let enumerator = FileManager.default.enumerator(
                at: directory, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey])
        else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }

    private static func pageName(index: Int, sourceURL: URL) -> String {
        let known: Set<String> = ["jpg", "jpeg", "png", "webp", "gif", "avif", "heic"]
        let ext = sourceURL.pathExtension.lowercased()
        let suffix = known.contains(ext) ? ext : "img"
        return String(format: "page-%04d.", index + 1) + suffix
    }
}
