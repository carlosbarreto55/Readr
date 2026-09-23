# library-browse-catalog

## Purpose

Defines library membership and the catalog surfaces — Library and Browse — that
present series as a grid.
## Requirements
### Requirement: Library membership SHALL persist locally

Adding a series to the library MUST persist it, and it MUST survive relaunch
without requiring the originating source to be reachable.

#### Scenario: A series is added

- **WHEN** the user adds a series from a catalog or detail screen
- **THEN** it SHALL be persisted with its `(sourceID, url)` identity
- **AND** it SHALL appear in the Library tab immediately

#### Scenario: The app relaunches offline

- **WHEN** the app is relaunched with no network
- **THEN** the library SHALL display every saved series with its stored metadata

#### Scenario: A series is removed

- **WHEN** the user removes a series from the library
- **THEN** its membership and chapter state SHALL be deleted
- **AND** its downloaded chapter payloads SHALL also be deleted

### Requirement: Catalogs SHALL present series as a grid of cards

Library and Browse MUST render results through the same catalog grid component so
the two surfaces stay visually consistent.

#### Scenario: A catalog renders

- **WHEN** series are displayed in Library or Browse
- **THEN** each SHALL show its cover, title, and source
- **AND** both surfaces SHALL use the shared grid component

#### Scenario: A cover fails to load

- **WHEN** a cover image cannot be fetched
- **THEN** a placeholder SHALL be shown
- **AND** the title SHALL remain readable

### Requirement: Empty and loading states SHALL be explicit

Every catalog surface MUST distinguish loading, empty, and error states.

#### Scenario: The library is empty

- **WHEN** no series have been added
- **THEN** an empty state SHALL explain how to add one
- **AND** it SHALL NOT be presented as an error

#### Scenario: A catalog request fails

- **WHEN** a Browse request throws
- **THEN** an error state with a retry action SHALL be shown

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
