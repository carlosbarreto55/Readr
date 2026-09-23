# download-offline-reader

## Purpose

Defines how stored chapter payloads are served to the Reader, so downloaded
chapters read without a network.
## Requirements
### Requirement: Downloaded content SHALL be preferred over remote

When a chapter is stored locally, the repository MUST serve the stored payload
rather than fetching it.

#### Scenario: A downloaded chapter is opened

- **WHEN** the Reader requests content for a chapter stored locally
- **THEN** the stored payload SHALL be returned
- **AND** no network request SHALL be issued

#### Scenario: A downloaded chapter is opened offline

- **WHEN** the device has no network and the chapter is stored
- **THEN** the chapter SHALL open and render normally

#### Scenario: A forced refresh is requested

- **WHEN** the caller explicitly requests a bypass of stored content
- **THEN** the remote source SHALL be used even if a payload exists

### Requirement: Stored payloads SHALL be self-contained

A downloaded chapter MUST include every asset needed to render it offline.

#### Scenario: An image-page chapter is downloaded

- **WHEN** a manhwa chapter is downloaded
- **THEN** every page image SHALL be stored locally
- **AND** the stored content SHALL reference local files, not remote URLs

#### Scenario: A download is incomplete

- **WHEN** some assets of a chapter failed to store
- **THEN** the chapter SHALL NOT be reported as downloaded
- **AND** the partial payload SHALL be discarded

### Requirement: Storage SHALL be located and excluded from backup

Payloads MUST live under Application Support and MUST be excluded from iCloud
backup.

#### Scenario: A payload is written

- **WHEN** a chapter payload is stored
- **THEN** it SHALL be written under
  `Application Support/Readr/Downloads/<sourceID>/<seriesKey>/<chapterKey>/`
- **AND** the `Downloads` directory SHALL have `isExcludedFromBackup` set

#### Scenario: A series is removed from the library

- **WHEN** a series is removed
- **THEN** its stored payloads SHALL be deleted
- **AND** the freed space SHALL be reflected in reported storage usage

### Requirement: Stored chapters SHALL be deletable

The reader MUST be able to delete one stored chapter, and every stored chapter at
once. Deletion MUST remove the payload from disk, and reported storage usage MUST
reflect the space freed.

#### Scenario: One stored chapter is deleted

- **WHEN** the reader deletes a downloaded chapter
- **THEN** its payload SHALL be removed from disk
- **AND** it SHALL no longer be reported as downloaded
- **AND** opening it SHALL fetch from the source

#### Scenario: All downloads are deleted

- **WHEN** the reader deletes every download
- **THEN** no chapter SHALL be reported as downloaded
- **AND** reported storage usage SHALL be zero

