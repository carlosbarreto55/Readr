import SwiftData

/// The schema the app currently writes.
///
/// `SeriesEntity` and `ChapterEntity` are aliases for this version's models, so
/// repositories and mappers name the current models without naming a version.
typealias CurrentSchema = SchemaV2

/// How the store moves between schema versions.
///
/// The container is opened through this plan from the first release, so every
/// schema change is a stage rather than a rewrite.
///
/// Destructive migration is forbidden. A container that fails to open leaves the
/// store intact and surfaces the failure — deleting the store to resolve a schema
/// mismatch destroys the reader's library and all of their progress.
enum ReadrMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2]
    }

    /// Adds each chapter's source position and whether its source still lists it.
    /// Both attributes are defaulted, so existing rows arrive at position 0 and
    /// listed; the next refresh assigns real positions.
    static let v1ToV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}
