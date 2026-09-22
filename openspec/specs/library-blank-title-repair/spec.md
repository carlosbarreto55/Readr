# library-blank-title-repair

## Purpose

Defines recovery for saved series whose title is missing or blank, so a parsing
failure at save time does not leave a permanently unidentifiable library entry.

## Requirements

### Requirement: Blank-titled series SHALL be repaired on refresh

A saved series with an empty or whitespace-only title MUST have its title
re-fetched from its source when the library is refreshed.

#### Scenario: A blank title is detected

- **WHEN** the library refreshes and a saved series has a blank title
- **THEN** its details SHALL be re-fetched from its source
- **AND** a non-blank title SHALL replace the blank one

#### Scenario: The repair fetch fails

- **WHEN** the re-fetch throws
- **THEN** the series SHALL remain saved with its blank title
- **AND** the repair SHALL be retried on the next refresh

#### Scenario: The source still returns no title

- **WHEN** the re-fetch succeeds but yields no title
- **THEN** the series SHALL remain saved
- **AND** it SHALL be displayed with a placeholder derived from its URL

### Requirement: A blank title SHALL NOT break identity or display

A blank title MUST NOT prevent a series from being displayed, opened, or removed.

#### Scenario: A blank-titled series is displayed

- **WHEN** a blank-titled series appears in the library grid
- **THEN** it SHALL render with a placeholder label
- **AND** it SHALL remain tappable and removable

#### Scenario: A blank-titled series is indexed

- **WHEN** a blank-titled series would be written to Spotlight
- **THEN** the placeholder label SHALL be indexed rather than an empty string
