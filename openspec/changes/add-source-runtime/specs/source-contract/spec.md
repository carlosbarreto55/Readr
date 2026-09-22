## MODIFIED Requirements

### Requirement: A source SHALL implement exactly one content shape

A plugin MUST return `.text(html:)` for novel sources or `.pages(imageURLs:)` for
manhwa sources, never both. A plugin that implements neither MUST throw when
chapter content is requested; it MUST NOT return an empty or placeholder value.

#### Scenario: A novel source returns content

- **WHEN** a source declaring `ContentType.novel` returns chapter content
- **THEN** it SHALL return `.text(html:)`

#### Scenario: A manhwa source returns content

- **WHEN** a source declaring `ContentType.manhwa` returns chapter content
- **THEN** it SHALL return `.pages(imageURLs:)` in reading order

#### Scenario: A plugin implements neither content shape

- **WHEN** chapter content is requested from a plugin that implements neither
  shape
- **THEN** it SHALL throw an error naming the source and the shape its declared
  `ContentType` requires
- **AND** it SHALL NOT return empty text or an empty page list, because an empty
  chapter is indistinguishable from a chapter that failed to parse

## ADDED Requirements

### Requirement: Shared source base types SHALL stay site-agnostic

A base type shared by plugins — such as `HTMLSource` — MUST contain no logic
specific to any one site. Site-specific parsing MUST live in the plugin.

#### Scenario: A site needs parsing the base type does not provide

- **WHEN** a site requires extraction the shared base type does not offer
- **THEN** the behavior SHALL be implemented in that site's own plugin
- **AND** it SHALL NOT be added to the shared base type

#### Scenario: Two sites need the same behavior

- **WHEN** a second site needs behavior a first site already implements
- **THEN** it MAY be promoted into the shared base type only if it names no site
- **AND** a promotion that names a site SHALL be rejected

### Requirement: Rules a plugin must follow SHALL be enforced by the base type

Where a shared base type exists, a rule every plugin must follow MUST be applied
by the base type rather than left for each plugin to repeat.

#### Scenario: Detail data is merged onto catalog data

- **WHEN** a plugin built on the shared base type returns parsed detail fields
- **THEN** the base type SHALL perform the merge that preserves previously known
  values
- **AND** the plugin SHALL NOT perform the merge itself, so that it cannot omit it

#### Scenario: A plugin is added

- **WHEN** a new plugin is written against the shared base type
- **THEN** it SHALL supply only site-specific URLs, selectors, and extraction
- **AND** fetching, timeout, concurrency bounding, and caching SHALL already
  apply to it without it opting in
