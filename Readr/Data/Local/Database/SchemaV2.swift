import SwiftData

/// Adds chapter source position and upstream presence.
///
/// The models live beside their mappers in `SeriesEntity.swift` and
/// `ChapterEntity.swift`; the top-level names alias this version.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SeriesEntity.self, ChapterEntity.self]
    }
}
