## ADDED Requirements

### Requirement: Comics SHALL be independently filterable in the library

The content filter MUST offer Comics as a distinct choice, MUST preserve the existing novel, manhwa, and manga choices, and MUST persist the comics selection on relaunch.

#### Scenario: Comics filter is selected

- **WHEN** the user selects Comics in a library containing all four content types
- **THEN** only comics SHALL be displayed and no library membership SHALL change

#### Scenario: Comics filter is restored

- **WHEN** the app relaunches after Comics was selected
- **THEN** the Comics filter SHALL remain selected
