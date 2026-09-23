## ADDED Requirements

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
