## ADDED Requirements

### Requirement: Stored chapters SHALL be presented in reading order

Each stored chapter MUST record the position its source most recently listed it
at, and the stored chapters of a series MUST be presented in one reading order —
first chapter first — regardless of whether the source lists newest-first or
oldest-first.

#### Scenario: A source lists newest chapters first

- **WHEN** a numbered chapter list is stored in descending order
- **THEN** the chapters SHALL be presented in ascending chapter order

#### Scenario: A source lists chapters without numbers

- **WHEN** the stored chapters carry no chapter numbers
- **THEN** they SHALL be presented in the order the source listed them

#### Scenario: A chapter is no longer listed upstream

- **WHEN** a stored chapter was absent from the latest refresh
- **THEN** it SHALL keep its last known position in the reading order
