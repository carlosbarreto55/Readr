# source-listing-pagination

## Purpose

Defines how catalog listings page through a source, so browsing does not
re-request, skip, or silently stall at a page boundary.

## Requirements

### Requirement: Catalog listings SHALL be paged explicitly

`popular(page:)`, `latest(page:)`, and `search(query:page:filters:)` MUST accept a
1-based page index and return a `SeriesPage` carrying its entries and a
`hasMore` flag.

#### Scenario: First page is requested

- **WHEN** a catalog is opened
- **THEN** the source SHALL be called with page 1

#### Scenario: More results exist

- **WHEN** a source returns a page and further pages are available
- **THEN** `hasMore` SHALL be `true`

#### Scenario: Last page is reached

- **WHEN** a source returns the final page
- **THEN** `hasMore` SHALL be `false`
- **AND** the UI SHALL NOT request a further page

### Requirement: Paging SHALL NOT duplicate or drop entries

Successive pages MUST be appended in order, and an entry already present MUST NOT
be appended twice.

#### Scenario: Next page loads

- **WHEN** page N+1 arrives
- **THEN** its entries SHALL be appended after page N's entries in source order

#### Scenario: A duplicate entry arrives

- **WHEN** a page contains an entry whose `(sourceID, url)` is already loaded
- **THEN** the duplicate SHALL be discarded rather than appended

### Requirement: Only one page request SHALL be in flight per catalog

A catalog MUST NOT issue a new page request while one is already pending.

#### Scenario: The user scrolls rapidly

- **WHEN** a scroll triggers a load-more while a page request is pending
- **THEN** the new trigger SHALL be ignored
- **AND** exactly one request SHALL remain in flight

#### Scenario: A page request fails

- **WHEN** a page request throws
- **THEN** the pending flag SHALL be cleared
- **AND** the UI SHALL offer a retry that re-requests the same page index
