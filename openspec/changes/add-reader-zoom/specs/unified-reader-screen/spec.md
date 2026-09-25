## ADDED Requirements

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

## MODIFIED Requirements

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
