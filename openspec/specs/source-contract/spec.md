# source-contract

## Purpose

Defines the stable plugin boundary every supported site implements, and the rules
governing source identity and error propagation.
## Requirements
### Requirement: Every site SHALL integrate through the Source protocol

A supported site MUST be reachable only through the `Source` protocol. No layer
other than the composition root MUST import a concrete site type.

#### Scenario: A repository needs remote data

- **WHEN** a repository requires data from a site
- **THEN** it SHALL resolve the site via `SourceRegistry[sourceID]`
- **AND** it SHALL call only `Source` protocol members

#### Scenario: A presentation model needs a source

- **WHEN** a presentation model needs source metadata
- **THEN** it SHALL obtain it from a repository as domain `SourceInfo`
- **AND** it SHALL NOT reference `SourceRegistry` or any concrete source type

### Requirement: Source identity SHALL be stable and derived

`sourceID` MUST be produced by `computeSourceID(name:lang:type:)` using an
explicitly specified hash. Swift's `Hasher` MUST NOT be used.

#### Scenario: A source is registered

- **WHEN** a source plugin is added to the registry
- **THEN** its `id` SHALL come from `computeSourceID(name:lang:type:)`
- **AND** it SHALL NOT be a hand-picked literal

#### Scenario: The app relaunches

- **WHEN** the app is relaunched, reinstalled, or run on another device
- **THEN** `computeSourceID` SHALL return the same value for the same inputs
- **AND** previously stored library entries SHALL remain reachable

#### Scenario: The hash implementation changes

- **WHEN** a change would alter the output of `computeSourceID` for any existing
  input
- **THEN** the guard-rail test asserting a hardcoded expected value SHALL fail
- **AND** the implementation SHALL be corrected rather than the expectation
  updated

### Requirement: A source SHALL implement exactly one content shape

A plugin MUST return `.text(html:)` for novel sources or `.pages(imageURLs:)` for manhwa, manga, and comic sources, never both. A plugin that implements neither MUST throw when chapter content is requested; it MUST NOT return an empty or placeholder value.

#### Scenario: A novel source returns content

- **WHEN** a source declaring `ContentType.novel` returns chapter content
- **THEN** it SHALL return `.text(html:)`

#### Scenario: A manhwa source returns content

- **WHEN** a source declaring `ContentType.manhwa` returns chapter content
- **THEN** it SHALL return `.pages(imageURLs:)` in reading order

#### Scenario: A manga source returns content

- **WHEN** a source declaring `ContentType.manga` returns chapter content
- **THEN** it SHALL return `.pages(imageURLs:)` in reading order

#### Scenario: A comic source returns content

- **WHEN** a source declaring `ContentType.comic` returns chapter content
- **THEN** it SHALL return `.pages(imageURLs:)` in reading order

#### Scenario: A plugin implements neither content shape

- **WHEN** chapter content is requested from a plugin that implements neither shape
- **THEN** it SHALL throw an error naming the source and the shape its declared `ContentType` requires
- **AND** it SHALL NOT return empty text or an empty page list, because an empty chapter is indistinguishable from a chapter that failed to parse

### Requirement: Sources SHALL throw rather than absorb errors

A source MUST throw on failure. It MUST NOT log, catch and continue, or return an
empty or `nil` sentinel in place of an error.

#### Scenario: A request fails

- **WHEN** a network request or parse fails inside a source
- **THEN** the source SHALL throw
- **AND** the repository SHALL decide what the failure means for the user

#### Scenario: A page legitimately has no results

- **WHEN** a catalog page is reachable and parses but contains no entries
- **THEN** the source SHALL return an empty `SeriesPage` with `hasMore == false`
- **AND** it SHALL NOT throw, because empty is not an error

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

