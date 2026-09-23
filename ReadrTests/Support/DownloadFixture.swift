import Foundation
import SwiftData

@testable import Readr

/// A download repository over an in-memory store, a fresh payload directory, and
/// a scripted transport.
struct DownloadFixture {
    let repository: DefaultDownloadRepository
    let transport: ScriptedTransport
    let container: ModelContainer
    let store: ChapterPayloadStore

    static let seriesURL = URL(string: "https://example.test/series/one")!

    init(container: ModelContainer? = nil) throws {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let container =
            try container
            ?? ModelContainer(
                for: schema, migrationPlan: ReadrMigrationPlan.self,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let store = try ChapterPayloadStore(
            root: FileManager.default.temporaryDirectory
                .appending(path: "readr-downloads-\(UUID().uuidString)"))
        let transport = ScriptedTransport()
        self.repository = DefaultDownloadRepository(
            modelContainer: container, store: store, transport: transport)
        self.transport = transport
        self.container = container
        self.store = store
    }

    static func chapter(_ number: Int) -> Chapter {
        Chapter(
            sourceID: 42, seriesURL: seriesURL, url: seriesURL.appending(path: "c\(number)"),
            name: "Chapter \(number)", number: Double(number))
    }

    static func pageURLs(_ chapter: Int, count: Int) -> [URL] {
        (0..<count).map { URL(string: "https://cdn.test/\(chapter)/\($0).jpg")! }
    }

    func states() async throws -> [DownloadState] {
        try await repository.snapshot().entries.map(\.state)
    }
}
