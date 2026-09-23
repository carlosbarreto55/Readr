import Foundation

/// Cover thumbnails for indexed series, as local files Spotlight can read.
///
/// Caches rather than Application Support: every file is re-derivable from a
/// cover URL, so eviction costs one fetch, never data. Kept so a rebuild of the
/// index at launch does not re-fetch every cover in the library.
struct SpotlightThumbnailCache: Sendable {
    let directory: URL

    static func live() -> SpotlightThumbnailCache {
        let caches =
            (try? FileManager.default.url(
                for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return SpotlightThumbnailCache(
            directory: caches.appending(path: "Readr/SpotlightThumbnails"))
    }

    /// The cached thumbnail, if one is on disk.
    func cached(for id: SeriesID) -> URL? {
        let url = file(for: id)
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }

    /// Stores thumbnail bytes and returns the file, or `nil` if it cannot be written.
    func store(_ data: Data, for id: SeriesID) -> URL? {
        let url = file(for: id)
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func remove(_ id: SeriesID) {
        try? FileManager.default.removeItem(at: file(for: id))
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func file(for id: SeriesID) -> URL {
        directory.appending(
            path: "\(id.sourceID)-\(EntityKey.path(for: id.url)).img")
    }
}
