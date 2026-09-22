# preferences-store Specification

## Purpose

Defines how the reader's own choices — reader settings, filter and sort
selections, and the like — are read, written, and cleared, without any layer
above the data layer learning where they are kept.

Settings are the one piece of state the app stores that is neither library
content nor chapter content. Keeping them behind a contract is what lets the
storage mechanism change, lets presentation be tested with a fake, and gives
"clear every setting" a bound narrow enough to be safe: the namespace the app
writes under, never the whole `UserDefaults` domain it happens to share with the
system frameworks.

## Requirements
### Requirement: Preferences SHALL be reachable only through a domain contract

Reader-facing settings MUST be read and written through a domain protocol. No
layer above the data layer MUST name the underlying storage mechanism.

#### Scenario: A presentation model reads a preference

- **WHEN** a presentation model needs a stored setting
- **THEN** it SHALL obtain it through the settings contract it was given
- **AND** it SHALL NOT name the underlying storage

#### Scenario: The storage mechanism is replaced

- **WHEN** the implementation behind the contract is replaced
- **THEN** no domain or presentation code SHALL require changes

### Requirement: An unset preference SHALL resolve to a documented default

Reading a preference that has never been written MUST return that preference's
declared default. It MUST NOT fail, and MUST NOT return an empty or zero value
standing in for one.

#### Scenario: A preference has never been written

- **WHEN** a preference is read on a fresh install
- **THEN** its declared default SHALL be returned

#### Scenario: A stored value cannot be interpreted

- **WHEN** a stored preference cannot be read back as its declared type
- **THEN** the declared default SHALL be returned
- **AND** the read SHALL NOT fail

#### Scenario: A preference is written and read back

- **WHEN** a preference is written and then read
- **THEN** the written value SHALL be returned rather than the default

### Requirement: Preferences SHALL survive relaunch

A written preference MUST still be readable after the app is relaunched.

#### Scenario: The app is relaunched

- **WHEN** a preference is written and the app is relaunched
- **THEN** reading it SHALL return the written value

### Requirement: Preferences SHALL NOT hold user content or library state

Only the reader's own settings MUST be stored as preferences. Library membership,
chapter state, and chapter content MUST NOT be.

#### Scenario: A series is saved

- **WHEN** a series is added to the library
- **THEN** no part of it SHALL be written to the preferences store

#### Scenario: The preferences store is cleared

- **WHEN** every preference is cleared
- **THEN** the library and all chapter state SHALL be unaffected
- **AND** every preference SHALL resolve to its declared default

