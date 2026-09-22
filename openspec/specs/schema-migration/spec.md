# schema-migration

## Purpose

Defines how the SwiftData schema evolves, so a model change never costs the user
their library or reading progress.

## Requirements

### Requirement: Every schema change SHALL add a new versioned schema

A model change MUST introduce a new `VersionedSchema` and a corresponding
`SchemaMigrationPlan` stage. An existing version MUST NOT be edited in place.

#### Scenario: A property is added

- **WHEN** a property is added to a persisted model
- **THEN** a new `VersionedSchema` SHALL be defined
- **AND** a migration stage SHALL be appended to the plan

#### Scenario: An existing version is edited

- **WHEN** a change would modify an already-released `VersionedSchema`
- **THEN** the change SHALL be rejected in review
- **AND** a new version SHALL be added instead

### Requirement: Destructive migration SHALL be forbidden

The store MUST NOT be deleted or reset to resolve a schema mismatch.

#### Scenario: A migration fails at launch

- **WHEN** the container fails to open because migration failed
- **THEN** the existing store SHALL be left intact
- **AND** the failure SHALL be surfaced rather than resolved by deleting data

#### Scenario: A migration is lossy by necessity

- **WHEN** a change cannot preserve a field's data
- **THEN** it SHALL require explicit human approval before being written

### Requirement: Every migration SHALL ship a test

A migration MUST be covered by a test that opens a store written by the previous
schema and asserts the data survived.

#### Scenario: A migration is added

- **WHEN** a new migration stage is written
- **THEN** a test SHALL populate a store at the previous version, migrate it, and
  assert the migrated values

#### Scenario: A migration test is absent

- **WHEN** a schema change is submitted without a migration test
- **THEN** it SHALL be rejected in review

### Requirement: Identity SHALL be preserved across migrations

`(sourceID, url)` MUST continue to identify the same series and chapters after
any migration.

#### Scenario: A model is restructured

- **WHEN** a migration reshapes a persisted model
- **THEN** existing records SHALL remain reachable by their original
  `(sourceID, url)`
- **AND** downloaded payload paths SHALL remain valid
