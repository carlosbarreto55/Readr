# spotlight-indexable-series

## Purpose

Defines how saved series are exposed to Core Spotlight, and the rule that the
index is a projection of library state rather than a store of record.
## Requirements
### Requirement: Saved series SHALL be indexed in Spotlight

Adding a series to the library MUST add a corresponding `CSSearchableItem`
carrying its title, source, and cover thumbnail where available.

#### Scenario: A series is added to the library

- **WHEN** a series is saved
- **THEN** a searchable item SHALL be indexed with a unique identifier derived
  from `(sourceID, url)`

#### Scenario: Series metadata changes

- **WHEN** a saved series' title or cover changes after a detail refresh
- **THEN** its indexed item SHALL be updated

#### Scenario: A series is removed

- **WHEN** a series is removed from the library
- **THEN** its indexed item SHALL be deleted

### Requirement: The index SHALL be a projection, never a source of truth

Index state MUST be derivable entirely from library state. Loss of the index MUST
NOT cause loss of user data.

#### Scenario: The index is lost or corrupted

- **WHEN** the system discards the app's Spotlight index
- **THEN** the library SHALL remain complete and usable
- **AND** the index SHALL be rebuildable from stored library state

#### Scenario: Indexing fails

- **WHEN** an index write fails
- **THEN** the library operation that triggered it SHALL still succeed
- **AND** the failure SHALL NOT be surfaced as a user-facing error

### Requirement: Indexing SHALL NOT leak reading content

Only series-level metadata MUST be indexed. Chapter text and page images MUST NOT
be.

#### Scenario: A chapter is downloaded

- **WHEN** chapter content is stored locally
- **THEN** no chapter text or image SHALL be added to the Spotlight index

### Requirement: The index SHALL be rebuilt from the library

The Spotlight index MUST be rebuilt from stored library state at every launch and
whenever the reader asks for it, so an index the system discarded or that drifted
from the library is corrected without user data being consulted from it.

#### Scenario: The app launches

- **WHEN** the app launches
- **THEN** every saved series SHALL be indexed
- **AND** no series that is not saved SHALL remain indexed

#### Scenario: The reader rebuilds the index

- **WHEN** the reader asks Settings to rebuild the Spotlight index
- **THEN** the index SHALL be replaced by one derived from the library

