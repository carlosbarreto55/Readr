# library-filtering

## Purpose

Defines how the saved library is filtered and sorted, and how those choices
persist.
## Requirements
### Requirement: The library SHALL be filterable by content type and source

Filters MUST narrow the displayed set without modifying stored library
membership.

#### Scenario: A content-type filter is applied

- **WHEN** the user filters to novels
- **THEN** only novel series SHALL be displayed
- **AND** manhwa series SHALL remain in the library

#### Scenario: Filters exclude everything

- **WHEN** an active filter combination matches no series
- **THEN** an empty state SHALL indicate that filters are hiding results
- **AND** it SHALL offer to clear them

### Requirement: The library SHALL be sortable

Sort order MUST be user-selectable among title, date added, and last read.

#### Scenario: Sort is changed

- **WHEN** the user selects a different sort order
- **THEN** the displayed order SHALL update immediately

#### Scenario: A series has never been read

- **WHEN** sorting by last read and a series has no read history
- **THEN** it SHALL sort after all read series rather than being hidden

### Requirement: Filter and sort selections SHALL persist

Active filter and sort choices MUST be stored as preferences and restored on
relaunch.

#### Scenario: The app relaunches

- **WHEN** the app is relaunched after filters were applied
- **THEN** the previous filter and sort selection SHALL be restored

### Requirement: Manga SHALL be independently filterable in the library

The content filter MUST offer Manga as a distinct choice, preserve existing novel and manhwa choices, and persist the manga selection on relaunch.

#### Scenario: Manga filter is selected

- **WHEN** the user selects Manga in a library containing all three content types
- **THEN** only manga SHALL be displayed and no library membership SHALL change

#### Scenario: Manga filter is restored

- **WHEN** the app relaunches after Manga was selected
- **THEN** the Manga filter SHALL remain selected

