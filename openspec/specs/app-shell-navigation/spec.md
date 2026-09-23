# app-shell-navigation

## Purpose

Defines the app's four top-level destinations, how each keeps its own navigation
path, what a route must carry, and how a destination whose feature is not built
yet presents itself.
## Requirements
### Requirement: The app SHALL present four top-level destinations

Launching Readr MUST present Library, Browse, Downloads, and Settings as
concurrently reachable top-level destinations, each labelled and individually
selectable. Library MUST be the destination shown on a cold launch.

#### Scenario: The app is launched

- **WHEN** Readr is launched
- **THEN** Library, Browse, Downloads, and Settings SHALL all be reachable
- **AND** Library SHALL be the selected destination

#### Scenario: A top-level destination is selected

- **WHEN** the user selects a different top-level destination
- **THEN** that destination SHALL be shown
- **AND** the previously selected one's navigation path SHALL be unchanged

### Requirement: Each top-level destination SHALL own an independent navigation path

Every top-level destination MUST maintain its own navigation path. Selecting a
different destination MUST NOT clear, truncate, or reorder any other
destination's path.

#### Scenario: A path survives a switch away and back

- **WHEN** a route is pushed onto one destination's path, another destination is
  selected, and the first is selected again
- **THEN** the first destination's path SHALL still contain that route

#### Scenario: Paths do not interfere

- **WHEN** a route is pushed onto one destination's path
- **THEN** every other destination's path SHALL be unchanged

#### Scenario: A destination is returned to its root

- **WHEN** a destination's path is cleared
- **THEN** that destination SHALL show its root
- **AND** no other destination's path SHALL be affected

### Requirement: A route SHALL carry what its destination needs

A route value MUST carry every identifier its destination requires to load its
content, so a destination never reads ambient or global state to discover what it
is showing. Series and chapter routes MUST identify their subject the way
`architecture.md` requires identity to be expressed.

A chapter route MUST NOT be a case of any top-level destination's path. The Reader
is presented outside the tab chrome rather than pushed onto a path, per
`architecture.md` §9.

#### Scenario: A series destination is navigated to

- **WHEN** a route for a series is pushed onto a destination's path
- **THEN** it SHALL carry the source identifier and the series URL

#### Scenario: A chapter route is constructed

- **WHEN** a route value identifying a chapter is constructed
- **THEN** it SHALL carry the source identifier, the series URL, the chapter URL,
  and the content type
- **AND** it SHALL NOT be a case of any top-level destination's path

#### Scenario: Two routes refer to the same subject

- **WHEN** two route values identify the same series
- **THEN** they SHALL compare as equal

### Requirement: Unbuilt features SHALL state their absence

A top-level destination whose feature has not yet been implemented MUST say so in
place, naming the feature. It MUST NOT present a blank surface, a spinner that
never resolves, or an error.

#### Scenario: An unbuilt destination is opened

- **WHEN** the user opens a destination whose feature is not yet implemented
- **THEN** it SHALL display an explanation naming that feature
- **AND** it SHALL NOT be presented as a failure or as an empty result

#### Scenario: A feature is implemented

- **WHEN** a destination's feature is implemented
- **THEN** its placeholder SHALL be replaced by the feature
- **AND** the destination's position and label SHALL be unchanged

### Requirement: A destination SHALL stay navigable after the reader returns to it

Leaving a destination — by pushing another route or switching tabs — and
returning to it MUST NOT stop its items from navigating.

#### Scenario: The reader opens a route, goes back, and opens another

- **WHEN** the reader opens a route from a destination, returns to that
  destination, and opens a route from it again
- **THEN** the second route SHALL be pushed like the first

#### Scenario: The reader switches tabs and returns

- **WHEN** the reader switches to another tab and back
- **THEN** the destination's items SHALL still navigate

