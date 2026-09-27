## MODIFIED Requirements

### Requirement: Reader appearance SHALL be adjustable and SHALL persist

The Reader MUST offer a theme, a text font, a text size, and a manhwa page layout,
MUST apply a change immediately, and MUST restore the reader's choices on the
next launch. Text size MUST scale relative to the system Dynamic Type size rather
than replacing it. The reader theme MUST apply only to the Reader. Its Match App
choice, the default, MUST follow the app theme (`app-appearance`); its Light,
Sepia, and Dark choices MUST hold regardless of the app theme.

#### Scenario: The reader changes the theme

- **WHEN** a different reader theme is selected
- **THEN** the open chapter SHALL re-render in that theme without reloading
- **AND** screens outside the Reader SHALL keep their appearance after the
  Reader closes

#### Scenario: The reader theme matches the app

- **WHEN** the reader theme is Match App and the app theme is Dark
- **THEN** the Reader SHALL render in dark appearance

#### Scenario: A fixed reader theme overrides the app theme

- **WHEN** the reader theme is Sepia and the app theme is Dark
- **THEN** the Reader SHALL render in sepia

#### Scenario: The app is relaunched

- **WHEN** reader appearance was changed and the app is relaunched
- **THEN** the Reader SHALL open with the changed appearance

#### Scenario: The system text size changes

- **WHEN** the system Dynamic Type size is increased
- **THEN** chapter text SHALL grow, with the reader's text size applied on top
