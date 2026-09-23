## ADDED Requirements

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
