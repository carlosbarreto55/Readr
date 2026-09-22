# series-catalog-ui

## Purpose

Defines the shared catalog grid used by Library and Browse, and its behavior
under Dynamic Type and rotation on iPhone.

## Requirements

### Requirement: The catalog grid SHALL adapt its column count

Column count MUST be derived from available width rather than hardcoded, so the
grid reflows on rotation.

#### Scenario: The device rotates to landscape

- **WHEN** the device rotates
- **THEN** the grid SHALL reflow to the column count that fits the new width
- **AND** scroll position SHALL be preserved

#### Scenario: A very large Dynamic Type size is active

- **WHEN** an accessibility text size is selected
- **THEN** the grid SHALL reduce its column count rather than truncate titles

### Requirement: Cards SHALL honor Dynamic Type

Card text MUST scale with the user's text size setting. Fixed point sizes MUST
NOT be used.

#### Scenario: Text size is increased

- **WHEN** the user increases the system text size
- **THEN** card titles SHALL scale accordingly
- **AND** card height SHALL grow to fit rather than clipping text

#### Scenario: A title is long

- **WHEN** a title exceeds the space available
- **THEN** it SHALL wrap to a bounded line count and then truncate with an
  ellipsis

### Requirement: Per-item actions SHALL use platform affordances

Item actions MUST be offered through a context menu rather than a persistent
on-card control.

#### Scenario: The user long-presses a card

- **WHEN** a card receives a long press
- **THEN** a context menu SHALL offer the actions valid for that surface

#### Scenario: A card is tapped

- **WHEN** a card is tapped
- **THEN** the series detail screen SHALL be pushed
