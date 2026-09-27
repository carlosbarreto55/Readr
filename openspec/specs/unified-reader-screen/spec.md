# unified-reader-screen

## Purpose

Defines the single Reader destination that serves both novel and manhwa content,
its two renderers, and the immersive controls they share.
## Requirements
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
reserved for the system back gesture. Panning a zoomed page MUST NOT begin there
either.

#### Scenario: The user swipes from the leading edge

- **WHEN** a swipe begins at the leading screen edge
- **THEN** the system back gesture SHALL take precedence
- **AND** the Reader SHALL NOT treat it as a page turn

#### Scenario: The user swipes from the leading edge on a zoomed page

- **WHEN** a page is zoomed and a swipe begins at the leading screen edge
- **THEN** the system back gesture SHALL take precedence
- **AND** the Reader SHALL NOT pan the page

### Requirement: Reading progress SHALL be recorded

Progress MUST be persisted per chapter as the user reads, and a chapter MUST be
marked read on completion. Opening a chapter MUST NOT, by itself, count as
reading it: a chapter's progress and last-read time MUST NOT change until the
user has moved at least 5% of the chapter away from where it opened, or has
reached its end. Opening a chapter MUST still mark its series as read now.

#### Scenario: The user reads partway

- **WHEN** the user scrolls or pages partway through a chapter and leaves
- **THEN** the position SHALL be persisted
- **AND** reopening the chapter SHALL restore it

#### Scenario: The user reaches the end

- **WHEN** the user reaches the end of a chapter
- **THEN** it SHALL be marked read

#### Scenario: The user opens a chapter and backs out

- **WHEN** the user opens a chapter and leaves having moved less than 5% of it
- **THEN** the chapter's position, read state, and last-read time SHALL be
  unchanged
- **AND** the series SHALL be stamped as read now for the Library's Last Read
  sort

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

### Requirement: Manga page progression SHALL be right-to-left

Paged manga MUST place the first page at the right, advance toward the left, keep the chapter's original zero-based page index for progress, and restore that index on reopen. Vertical manga MUST remain in top-to-bottom source order.

#### Scenario: The user advances one manga page

- **WHEN** the first manga page is visible and the user pages leftward
- **THEN** the second source page SHALL appear and progress SHALL be page index 1

#### Scenario: A manga chapter is reopened

- **WHEN** a saved manga chapter is reopened at page index 4
- **THEN** the fifth source page SHALL be visible regardless of visual ordering

### Requirement: Continue Reading SHALL resume the chapter read most recently

The series screen's Continue Reading action MUST open the chapter the user read
most recently, meaning the chapter with the latest last-read time among
chapters that are read or partly read. If that chapter is partly read, Continue
MUST open it. If it is read, Continue MUST open the first unread chapter after
it, or the last chapter when none after it is unread. When no chapter has a
last-read time, Continue MUST open the first unread chapter after the last read
chapter, or the first chapter when none is read.

#### Scenario: The user leaves a chapter unfinished and reads on

- **WHEN** the user leaves chapter 1 partly read and then reads chapters 2 to 5
  to the end
- **THEN** Continue Reading SHALL open chapter 6

#### Scenario: The user stops partway through the latest chapter

- **WHEN** the chapter read most recently is partly read
- **THEN** Continue Reading SHALL open that chapter at its saved position

#### Scenario: The user opens an old chapter by mistake

- **WHEN** the user is partway through chapter 20, opens chapter 3, and leaves
  having moved less than 5% of it
- **THEN** Continue Reading SHALL still open chapter 20

#### Scenario: The user rereads an unfinished older chapter

- **WHEN** the user reads further into an older chapter that is partly read
- **THEN** Continue Reading SHALL open that older chapter

#### Scenario: Nothing carries a last-read time

- **WHEN** chapters were only marked read from the chapter list
- **THEN** Continue Reading SHALL open the first unread chapter after the last
  read chapter

### Requirement: Page chapters SHALL be zoomable in every layout

A page chapter MUST magnify under a pinch in both the vertical and the paged
layout, for manga and manhwa alike. The magnification MUST stay between 1× and
3×. Zooming MUST NOT move the reader away from the page they are reading, and it
MUST NOT change which page is recorded as their position. A single tap MUST keep
toggling the reader controls without delay.

#### Scenario: The reader pinches a vertical chapter

- **WHEN** the reader pinches outward on a chapter in the vertical layout
- **THEN** the pages SHALL magnify around the pinch
- **AND** the reader SHALL stay on the page they were reading

#### Scenario: The reader scrolls while zoomed in the vertical layout

- **WHEN** a vertical chapter is zoomed and the reader drags vertically
- **THEN** the chapter SHALL scroll on through later pages at the same zoom
- **AND** a horizontal drag SHALL pan across the magnified pages without passing
  their edges

#### Scenario: The reader drags a zoomed page in the paged layout

- **WHEN** a page in the paged layout is zoomed and the reader drags
- **THEN** the page SHALL pan in the drag's direction without passing its edges
- **AND** the page SHALL NOT turn

#### Scenario: The reader zooms back out in the paged layout

- **WHEN** a zoomed page is pinched back to 1×
- **THEN** horizontal drags SHALL turn pages again

#### Scenario: The reader pinches past the limits

- **WHEN** the reader pinches beyond 3× or below 1×
- **THEN** the magnification SHALL stop at 3× or 1× respectively

#### Scenario: The chapter or layout changes

- **WHEN** the reader moves to another chapter or switches the page layout
- **THEN** the new chapter or layout SHALL open at 1×

#### Scenario: The reader taps a page

- **WHEN** the reader taps once on a page chapter, zoomed or not
- **THEN** the reader controls SHALL toggle without waiting for a second tap

### Requirement: Text chapters SHALL resize under a pinch

A pinch on a text chapter MUST change the reader's text size rather than magnify
the page. It MUST use the same size range and steps as the text size setting.
The text MUST reflow as the size changes, the reader MUST stay at the passage
they were reading, and the resulting size MUST persist like a change made in
settings.

#### Scenario: The reader pinches outward on a text chapter

- **WHEN** the reader pinches outward on a text chapter
- **THEN** the text SHALL grow in text-size steps and reflow to the screen width
- **AND** the passage at the top of the screen SHALL stay in view

#### Scenario: The reader pinches past the text size limits

- **WHEN** the reader pinches beyond the largest or smallest text size
- **THEN** the text size SHALL stop at that limit

#### Scenario: The reader reopens the Reader after a pinch

- **WHEN** the reader changed the text size by pinching and opens another text
  chapter
- **THEN** that chapter SHALL open at the pinched text size

### Requirement: Comic page progression SHALL be left-to-right

Paged comics MUST place the first page at the left and advance toward the right. They MUST keep the issue's original zero-based page index for progress and restore that index on reopen. Vertical comics MUST remain in top-to-bottom source order.

#### Scenario: The user advances one comic page

- **WHEN** the first comic page is visible and the user pages forward
- **THEN** the second source page SHALL appear and progress SHALL be page index 1

#### Scenario: A comic issue is reopened

- **WHEN** a saved comic issue is reopened at page index 4
- **THEN** the fifth source page SHALL be visible in either layout

