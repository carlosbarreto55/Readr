## MODIFIED Requirements

### Requirement: Both content types SHALL use one Reader destination

Novel, manhwa, and manga chapters MUST open the same Reader destination, screen, model, and state. The destination MUST carry source ID, series URL, chapter URL, and content type.

#### Scenario: A novel chapter opens

- **WHEN** the user selects a chapter from a novel series
- **THEN** navigation SHALL open the shared Reader destination with `ContentType.novel`

#### Scenario: A manhwa chapter opens

- **WHEN** the user selects a chapter from a manhwa series
- **THEN** navigation SHALL open the same Reader destination with `ContentType.manhwa`

#### Scenario: A manga chapter opens

- **WHEN** the user selects a chapter from a manga series
- **THEN** navigation SHALL open the same Reader destination with `ContentType.manga`

#### Scenario: The model initializes from route context

- **WHEN** the Reader model is created
- **THEN** it SHALL initialize from source ID, series URL, chapter URL, and content type
- **AND** it SHALL NOT access `SourceRegistry` or a concrete source

### Requirement: Reader appearance SHALL be adjustable and SHALL persist

The Reader MUST offer a theme, a text font, a text size, a manhwa page layout, and a separate manga page layout, MUST apply a change immediately, and MUST restore the reader's choices on the next launch. Manga MUST default to paged right-to-left; manhwa MUST retain its vertical default. Text size MUST scale relative to the system Dynamic Type size rather than replacing it.

#### Scenario: The reader changes the theme

- **WHEN** a different reader theme is selected
- **THEN** the open chapter SHALL re-render in that theme without reloading

#### Scenario: The app is relaunched

- **WHEN** reader appearance was changed and the app is relaunched
- **THEN** the Reader SHALL open with the changed appearance

#### Scenario: The system text size changes

- **WHEN** the system Dynamic Type size is increased
- **THEN** chapter text SHALL grow, with the reader's text size applied on top

#### Scenario: Manga is opened with default preferences

- **WHEN** a manga chapter is opened before its layout has been customized
- **THEN** it SHALL open in right-to-left paged layout without changing the manhwa layout preference

## ADDED Requirements

### Requirement: Manga page progression SHALL be right-to-left

Paged manga MUST place the first page at the right, advance toward the left, keep the chapter's original zero-based page index for progress, and restore that index on reopen. Vertical manga MUST remain in top-to-bottom source order.

#### Scenario: The user advances one manga page

- **WHEN** the first manga page is visible and the user pages leftward
- **THEN** the second source page SHALL appear and progress SHALL be page index 1

#### Scenario: A manga chapter is reopened

- **WHEN** a saved manga chapter is reopened at page index 4
- **THEN** the fifth source page SHALL be visible regardless of visual ordering

