## MODIFIED Requirements

### Requirement: Both content types SHALL use one Reader destination

Novel, manhwa, manga, and comic chapters MUST open the same Reader destination, screen, model, and state. The destination MUST carry source ID, series URL, chapter URL, and content type.

#### Scenario: A novel chapter opens

- **WHEN** the user selects a chapter from a novel series
- **THEN** navigation SHALL open the shared Reader destination with `ContentType.novel`

#### Scenario: A manhwa chapter opens

- **WHEN** the user selects a chapter from a manhwa series
- **THEN** navigation SHALL open the same Reader destination with `ContentType.manhwa`

#### Scenario: A manga chapter opens

- **WHEN** the user selects a chapter from a manga series
- **THEN** navigation SHALL open the same Reader destination with `ContentType.manga`

#### Scenario: A comic issue opens

- **WHEN** the user selects an issue from a comic series
- **THEN** navigation SHALL open the same Reader destination with `ContentType.comic`

#### Scenario: The model initializes from route context

- **WHEN** the Reader model is created
- **THEN** it SHALL initialize from source ID, series URL, chapter URL, and content type
- **AND** it SHALL NOT access `SourceRegistry` or a concrete source

### Requirement: Reader appearance SHALL be adjustable and SHALL persist

The Reader MUST offer a theme, a text font, a text size, a manhwa page layout, a separate manga page layout, and a separate comic page layout. It MUST apply a change immediately and MUST restore the reader's choices on the next launch. Manga MUST default to paged right-to-left, comics MUST default to paged left-to-right, and manhwa MUST retain its vertical default. Text size MUST scale relative to the system Dynamic Type size rather than replacing it. The reader theme MUST apply only to the Reader. Its Match App choice, the default, MUST follow the app theme (`app-appearance`); its Light, Sepia, and Dark choices MUST hold regardless of the app theme.

#### Scenario: The reader changes the theme

- **WHEN** a different reader theme is selected
- **THEN** the open chapter SHALL re-render in that theme without reloading
- **AND** screens outside the Reader SHALL keep their appearance after the Reader closes

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

#### Scenario: Manga is opened with default preferences

- **WHEN** a manga chapter is opened before its layout has been customized
- **THEN** it SHALL open in right-to-left paged layout without changing the manhwa layout preference

#### Scenario: A comic is opened with default preferences

- **WHEN** a comic issue is opened before its layout has been customized
- **THEN** it SHALL open in left-to-right paged layout

#### Scenario: The reader switches comics to vertical

- **WHEN** the reader selects the vertical layout while a comic issue is open, or selects it for comics in Settings
- **THEN** comic issues SHALL render top-to-bottom in source order
- **AND** the manhwa and manga layout preferences SHALL be unchanged

## ADDED Requirements

### Requirement: Comic page progression SHALL be left-to-right

Paged comics MUST place the first page at the left and advance toward the right. They MUST keep the issue's original zero-based page index for progress and restore that index on reopen. Vertical comics MUST remain in top-to-bottom source order.

#### Scenario: The user advances one comic page

- **WHEN** the first comic page is visible and the user pages forward
- **THEN** the second source page SHALL appear and progress SHALL be page index 1

#### Scenario: A comic issue is reopened

- **WHEN** a saved comic issue is reopened at page index 4
- **THEN** the fifth source page SHALL be visible in either layout
