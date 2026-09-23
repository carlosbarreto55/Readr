## ADDED Requirements

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
