## ADDED Requirements

### Requirement: The app theme SHALL be set from Settings and SHALL apply everywhere

Settings MUST offer an app theme with the choices System, Light, and Dark. A
change MUST apply immediately to every screen of the app, without a relaunch.
System MUST follow the device appearance, including when it changes while the
app is running. System MUST be the default.

#### Scenario: The reader picks a dark app theme

- **WHEN** the app theme is set to Dark in Settings
- **THEN** every tab SHALL render in dark appearance immediately

#### Scenario: The app theme follows the system

- **WHEN** the app theme is System and the device appearance changes
- **THEN** the app SHALL change appearance with it

#### Scenario: A fresh install

- **WHEN** the app is launched with no stored app theme
- **THEN** the app theme SHALL be System

### Requirement: The app theme SHALL persist and SHALL be cleared by Reset Settings

The chosen app theme MUST be restored on the next launch. Reset Settings MUST
return it to System and MUST apply that immediately.

#### Scenario: The app is relaunched

- **WHEN** the app theme was changed and the app is relaunched
- **THEN** the app SHALL open in the chosen app theme

#### Scenario: Settings are reset

- **WHEN** the reader confirms Reset Settings
- **THEN** the app theme SHALL be System
- **AND** the app SHALL follow the device appearance immediately

### Requirement: The app theme and the reader theme SHALL be independent

Changing the app theme MUST NOT change the stored reader theme, and changing the
reader theme MUST NOT change the app theme.

#### Scenario: The app theme changes

- **WHEN** the app theme is changed
- **THEN** the stored reader theme SHALL be unchanged

#### Scenario: The reader theme changes

- **WHEN** the reader theme is changed, from Settings or from the Reader
- **THEN** the app theme SHALL be unchanged
- **AND** screens outside the Reader SHALL keep their appearance
