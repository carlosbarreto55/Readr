# source-detail-parsing

## Purpose

Defines what a source must produce when asked for full series details, and how
partial catalog data is merged with it.

## Requirements

### Requirement: Detail fetches SHALL enrich rather than replace

`seriesDetails(for:)` MUST return a `Series` that preserves identity and MUST NOT
discard known values by overwriting them with empty ones.

#### Scenario: Details arrive for a catalog entry

- **WHEN** details are fetched for a series already known from a catalog listing
- **THEN** the returned series SHALL retain the same `(sourceID, url)`
- **AND** populated fields SHALL replace the catalog values

#### Scenario: A field is absent from the detail page

- **WHEN** the detail page omits a field the catalog listing provided
- **THEN** the previously known value SHALL be preserved
- **AND** it SHALL NOT be overwritten with an empty string or empty array

### Requirement: Unparseable optional fields SHALL degrade, not fail

A missing or unrecognized optional field MUST NOT cause the detail fetch to throw.

#### Scenario: Status is unrecognized

- **WHEN** the site reports a series status the source does not recognize
- **THEN** `SeriesStatus.unknown` SHALL be used
- **AND** the fetch SHALL succeed

#### Scenario: Genres are absent

- **WHEN** no genres can be parsed
- **THEN** an empty genre list SHALL be returned
- **AND** the fetch SHALL succeed

### Requirement: Required identity fields SHALL fail loudly

If a title or chapter-list anchor cannot be parsed, the source MUST throw.

#### Scenario: The title cannot be parsed

- **WHEN** the detail page yields no title
- **THEN** the source SHALL throw rather than return a blank-titled series
