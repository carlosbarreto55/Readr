# unified-reader-screen

## Purpose

Defines the single Reader destination that serves both novel and manhwa content,
its two renderers, and the immersive controls they share.
## Requirements
### Requirement: Both content types SHALL use one Reader destination

Novel and manhwa chapters MUST open the same Reader destination, screen, model,
and state. The destination MUST carry source ID, series URL, chapter URL, and
content type.

#### Scenario: A novel chapter opens

- **WHEN** the user selects a chapter from a novel series
- **THEN** navigation SHALL open the shared Reader destination with
  `ContentType.novel`

#### Scenario: A manhwa chapter opens

- **WHEN** the user selects a chapter from a manhwa series
- **THEN** navigation SHALL open the same Reader destination with
  `ContentType.manhwa`

#### Scenario: The model initializes from route context

- **WHEN** the Reader model is created
- **THEN** it SHALL initialize from source ID, series URL, chapter URL, and
  content type
- **AND** it SHALL NOT access `SourceRegistry` or a concrete source

### Requirement: Reader SHALL render exactly the two content shapes

`.text(html:)` MUST render through the attributed-text renderer and
`.pages(imageURLs:)` through the image-page renderer.

#### Scenario: Text content loads

- **WHEN** the chapter repository returns `.text(html:)`
- **THEN** the Reader SHALL render it as attributed text honoring Dynamic Type
  and the selected reader theme

#### Scenario: Page content loads

- **WHEN** the chapter repository returns `.pages(imageURLs:)`
- **THEN** the Reader SHALL display the images in reading order

#### Scenario: Route type and content disagree

- **WHEN** loaded content does not match the route's content type
- **THEN** the Reader SHALL perform one forced network fetch bypassing downloaded
  content
- **AND** it SHALL NOT render the mismatched payload

#### Scenario: Forced content still disagrees

- **WHEN** the forced fetch still does not match the route content type
- **THEN** the Reader SHALL show a retryable unexpected-content error

### Requirement: Reader SHALL provide shared immersive controls

Both renderers MUST use the same tap-to-toggle overlay chrome offering back,
previous chapter, next chapter, chapter list, download, and progress.

#### Scenario: The reading surface is tapped

- **WHEN** the user taps the reading surface
- **THEN** the top and bottom controls SHALL toggle visibility

#### Scenario: Controls are hidden

- **WHEN** controls are hidden
- **THEN** the status bar and home indicator SHALL also be hidden

#### Scenario: The first chapter is open

- **WHEN** the current chapter is the first in the series
- **THEN** the previous-chapter control SHALL be disabled rather than absent

### Requirement: Reader gestures SHALL NOT conflict with system gestures

A horizontal paging gesture MUST NOT begin within the leading screen-edge region
reserved for the system back gesture.

#### Scenario: The user swipes from the leading edge

- **WHEN** a swipe begins at the leading screen edge
- **THEN** the system back gesture SHALL take precedence
- **AND** the Reader SHALL NOT treat it as a page turn

### Requirement: Reading progress SHALL be recorded

Progress MUST be persisted per chapter as the user reads, and a chapter MUST be
marked read on completion.

#### Scenario: The user reads partway

- **WHEN** the user scrolls or pages partway through a chapter and leaves
- **THEN** the position SHALL be persisted
- **AND** reopening the chapter SHALL restore it

#### Scenario: The user reaches the end

- **WHEN** the user reaches the end of a chapter
- **THEN** it SHALL be marked read

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

### Requirement: Page images SHALL keep the reading position while they load

Loading, resizing, or re-creating page images MUST NOT move the reader away from
the page they are reading, and a page taller than the screen MUST scroll through
like any other content.

#### Scenario: A page below finishes loading

- **WHEN** the reader is on one page and a later page finishes loading
- **THEN** the reader SHALL stay on the page they were reading

#### Scenario: A page is taller than the screen

- **WHEN** a page image is several screens tall
- **THEN** the reader SHALL scroll through all of it and on to the next page

#### Scenario: A page is still loading

- **WHEN** a page's image has not loaded yet
- **THEN** its place SHALL show that it is loading

