## ADDED Requirements

### Requirement: Manga SHALL be independently filterable in the library

The content filter MUST offer Manga as a distinct choice, preserve existing novel and manhwa choices, and persist the manga selection on relaunch.

#### Scenario: Manga filter is selected

- **WHEN** the user selects Manga in a library containing all three content types
- **THEN** only manga SHALL be displayed and no library membership SHALL change

#### Scenario: Manga filter is restored

- **WHEN** the app relaunches after Manga was selected
- **THEN** the Manga filter SHALL remain selected

