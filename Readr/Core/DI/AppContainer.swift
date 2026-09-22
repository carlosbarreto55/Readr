import Foundation
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
///
/// At this milestone it owns the `URLSession` and the `SourceRegistry`. The
/// `ModelContainer` and the repositories join it with the persistence layer.
public final class AppContainer: Sendable {
    public let urlSession: URLSession
    public let sources: SourceRegistry

    public init(urlSession: URLSession = .shared, sources: SourceRegistry) {
        self.urlSession = urlSession
        self.sources = sources
    }

    /// The container the app runs with.
    ///
    /// Sources come from `liveSources()`, which is the only place concrete site
    /// types are imported.
    public static func live() -> AppContainer {
        AppContainer(sources: SourceRegistry(liveSources()))
    }
}

extension EnvironmentValues {
    /// The composition root. Defaults to an empty container so `#Preview` bodies
    /// and tests never need to build one.
    @Entry public var appContainer: AppContainer = AppContainer(sources: SourceRegistry([]))
}
