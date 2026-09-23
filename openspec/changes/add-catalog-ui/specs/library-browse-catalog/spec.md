## ADDED Requirements

### Requirement: Browse SHALL expose each registered source's catalogs

Browse MUST list source metadata supplied by the catalog repository and MUST let
the reader open a source's popular catalog, latest catalog, and text search
without presentation code referencing a concrete source.

#### Scenario: A registered source is selected

- **WHEN** the reader selects a source from the Browse root
- **THEN** that source's catalog SHALL be pushed through typed navigation
- **AND** its first popular page SHALL be requested

#### Scenario: The catalog mode is changed

- **WHEN** the reader switches between Popular and Latest
- **THEN** the selected operation SHALL restart from page one
- **AND** entries from the previous operation SHALL NOT remain in the grid

#### Scenario: A text search is submitted

- **WHEN** the reader submits a non-empty search query
- **THEN** the selected source's search operation SHALL restart from page one
- **AND** subsequent paging SHALL continue that submitted query

#### Scenario: Search is cleared

- **WHEN** the reader clears an active search query and submits it
- **THEN** Browse SHALL return to the selected Popular or Latest catalog from
  page one
