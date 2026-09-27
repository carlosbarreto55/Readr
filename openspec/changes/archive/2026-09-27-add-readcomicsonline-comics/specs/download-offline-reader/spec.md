## MODIFIED Requirements

### Requirement: Stored payloads SHALL be self-contained

A downloaded chapter MUST include every asset needed to render it offline.

#### Scenario: An image-page chapter is downloaded

- **WHEN** a manhwa or manga chapter, or a comic issue, is downloaded
- **THEN** every page image SHALL be stored locally
- **AND** the stored content SHALL reference local files, not remote URLs

#### Scenario: A download is incomplete

- **WHEN** some assets of a chapter failed to store
- **THEN** the chapter SHALL NOT be reported as downloaded
- **AND** the partial payload SHALL be discarded
