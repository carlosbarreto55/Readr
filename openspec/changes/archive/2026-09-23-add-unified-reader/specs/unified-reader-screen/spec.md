## ADDED Requirements

### Requirement: Reader appearance SHALL be adjustable and SHALL persist

The Reader MUST offer a theme, a text font, a text size, and a manhwa page layout,
MUST apply a change immediately, and MUST restore the reader's choices on the
next launch. Text size MUST scale relative to the system Dynamic Type size rather
than replacing it.

#### Scenario: The reader changes the theme

- **WHEN** a different reader theme is selected
- **THEN** the open chapter SHALL re-render in that theme without reloading

#### Scenario: The app is relaunched

- **WHEN** reader appearance was changed and the app is relaunched
- **THEN** the Reader SHALL open with the changed appearance

#### Scenario: The system text size changes

- **WHEN** the system Dynamic Type size is increased
- **THEN** chapter text SHALL grow, with the reader's text size applied on top

### Requirement: Chapters outside the library SHALL be readable without stored progress

A chapter of a series that is not in the library MUST open and render normally.
Its progress MUST NOT be persisted, and the Reader MUST say so rather than imply
that it was.

#### Scenario: An unsaved series' chapter is opened

- **WHEN** the reader opens a chapter of a series not in the library
- **THEN** the chapter SHALL render
- **AND** the Reader SHALL indicate that progress is saved only for library series

#### Scenario: An unsaved chapter is read to the end

- **WHEN** the reader reaches the end of a chapter of an unsaved series
- **THEN** no library record SHALL be created or changed
