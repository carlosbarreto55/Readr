import Foundation
import SwiftData
import SwiftUI

/// The composition root.
///
/// Built once in `ReadrApp` and reached through the SwiftUI environment. Views
/// never construct dependencies; presentation models receive what they need
/// through `init`, which is what lets them be tested with hand-rolled fakes and no
/// container at all.
///
/// It is `Sendable` rather than main-actor-bound because background tasks reuse
/// the same repository, source, and storage graph outside the UI lifecycle
/// (`architecture.md` §7.1).
public final class AppContainer: Sendable {
    public let urlSession: URLSession
    public let sources: SourceRegistry

    /// Deliberately not `public`. The container reaches every view through the
    /// environment, so a public `ModelContainer` would hand any SwiftUI view a
    /// supported route to a `ModelContext` — which `Readr/UI/AGENTS.md` forbids
    /// outright. The store is reachable only through a repository.
    private let modelContainer: ModelContainer

    public let library: any LibraryRepository
    public let settings: any SettingsStore

    public init(
        urlSession: URLSession = .shared,
        sources: SourceRegistry,
        modelContainer: ModelContainer,
        settings: any SettingsStore = UserDefaultsSettingsStore()
    ) {
        self.urlSession = urlSession
        self.sources = sources
        self.modelContainer = modelContainer
        self.settings = settings
        self.library = SwiftDataLibraryRepository(modelContainer: modelContainer)
    }

    /// The container the app runs with.
    ///
    /// - Throws: if the store cannot be opened. The caller surfaces that;
    ///   deleting the store to recover is forbidden, because it destroys the
    ///   reader's library and every chapter of progress they have.
    public static func live() throws -> AppContainer {
        AppContainer(sources: SourceRegistry(liveSources()), modelContainer: try makeStore())
    }

    /// A container backed by an in-memory store, for previews and tests.
    public static func inMemory(
        sources: SourceRegistry = SourceRegistry([])
    ) throws -> AppContainer {
        AppContainer(
            sources: sources,
            modelContainer: try makeStore(inMemory: true),
            settings: InMemorySettingsStore()
        )
    }

    private static func makeStore(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: ReadrMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        )
    }
}

extension EnvironmentValues {
    /// The composition root.
    ///
    /// Optional, and with no default, on purpose. A container built here as a
    /// convenience would hold an empty library and an empty registry, so a view
    /// that missed the injection would render as though the reader had saved
    /// nothing — the silent-empty failure `architecture.md` §4.1 warns about,
    /// reached by a different route. Absent is legible; empty is not.
    @Entry public var appContainer: AppContainer?
}
