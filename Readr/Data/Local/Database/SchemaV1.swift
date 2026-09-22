import Foundation
import SwiftData

/// The first released schema.
///
/// An existing version is never edited in place. A model change introduces a new
/// `VersionedSchema` and a corresponding stage in `ReadrMigrationPlan` — see the
/// `schema-migration` capability.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SeriesEntity.self, ChapterEntity.self]
    }
}

/// How the store moves between schema versions.
///
/// There is only one version and so no stage to run. That is the point of it
/// existing anyway: the container is opened through this plan from the first
/// release, so the first real schema change is a stage rather than a rewrite.
///
/// Destructive migration is forbidden. A container that fails to open leaves the
/// store intact and surfaces the failure — deleting the store to resolve a schema
/// mismatch destroys the reader's library and all of their progress.
enum ReadrMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
