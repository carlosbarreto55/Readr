## ADDED Requirements

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
