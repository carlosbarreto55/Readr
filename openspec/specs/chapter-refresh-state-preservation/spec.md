# chapter-refresh-state-preservation

## Purpose

Defines how a chapter list refresh merges remote data with locally held state, so
refreshing never discards read progress or downloaded content.

## Requirements

### Requirement: Refresh SHALL preserve local chapter state

Merging a refreshed chapter list MUST preserve read state, reading position, and
download state for chapters that still exist.

#### Scenario: A chapter list is refreshed

- **WHEN** a refreshed list contains a chapter already stored
- **THEN** its read state, position, and download state SHALL be preserved
- **AND** its remote metadata SHALL be updated

#### Scenario: New chapters appear

- **WHEN** the refreshed list contains chapters not previously stored
- **THEN** they SHALL be inserted as unread and not downloaded

#### Scenario: Chapter order changes

- **WHEN** the source reorders or renumbers chapters
- **THEN** state SHALL follow `(sourceID, url)` identity, not list position

### Requirement: Chapters absent from a refresh SHALL NOT be silently destroyed

A chapter missing from a refreshed list MUST NOT have downloaded content deleted
as part of the refresh.

#### Scenario: A chapter disappears from the source

- **WHEN** a previously known chapter is absent from the refreshed list
- **THEN** its stored record and downloaded payload SHALL be retained
- **AND** it SHALL be marked as no longer listed upstream

#### Scenario: A refresh returns an empty list

- **WHEN** a refresh yields no chapters at all
- **THEN** the existing stored chapters SHALL be left untouched
- **AND** the refresh SHALL be treated as failed rather than as an emptied series

### Requirement: A failed refresh SHALL leave state unchanged

If a refresh throws, no partial merge MUST be committed.

#### Scenario: The refresh request fails

- **WHEN** a chapter list refresh throws partway through
- **THEN** stored chapter state SHALL be exactly as it was before the refresh
