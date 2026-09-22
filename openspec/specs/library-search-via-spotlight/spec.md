# library-search-via-spotlight

## Purpose

Defines in-app library search and its relationship to the Core Spotlight index,
so the same query returns consistent results from inside and outside the app.

## Requirements

### Requirement: The library SHALL be searchable within the app

In-app search MUST match against saved series titles and MUST return results
without a network request.

#### Scenario: The user searches the library

- **WHEN** a query is entered in the Library search field
- **THEN** matching saved series SHALL be displayed
- **AND** no network request SHALL be issued

#### Scenario: The query matches nothing

- **WHEN** no saved series matches
- **THEN** an empty state SHALL be shown that distinguishes "no match" from "empty library"

#### Scenario: Search runs offline

- **WHEN** the device has no network
- **THEN** library search SHALL behave identically

### Requirement: Search SHALL be resilient to case and diacritics

Matching MUST be case-insensitive and diacritic-insensitive.

#### Scenario: Case differs

- **WHEN** the query differs from the stored title only in capitalization
- **THEN** the series SHALL match

#### Scenario: Diacritics differ

- **WHEN** the query omits diacritics present in the stored title
- **THEN** the series SHALL match

### Requirement: A Spotlight result SHALL open its series

Opening a Readr result from system search MUST navigate directly to that series.

#### Scenario: A Spotlight result is tapped

- **WHEN** the user opens a Readr result from system search
- **THEN** the app SHALL launch and navigate to that series' detail screen

#### Scenario: The indexed series no longer exists

- **WHEN** a Spotlight result refers to a series removed from the library
- **THEN** the app SHALL open without error and explain that the series is no
  longer saved
- **AND** the stale index entry SHALL be removed
