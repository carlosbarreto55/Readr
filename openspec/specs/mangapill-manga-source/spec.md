# mangapill-manga-source Specification

## Purpose
Defines how the MangaPill source discovers Japanese manga, parses series details
and chapters, and returns ordered page images that load online.

## Requirements
### Requirement: MangaPill SHALL expose Japanese manga through catalog and search

The registered MangaPill source SHALL identify its series as `ContentType.manga` and SHALL provide popular, latest, and query search listings using manga-only site routes.

#### Scenario: A manga listing is requested

- **WHEN** a user browses or searches MangaPill
- **THEN** the source SHALL return titled manga series with stable source and series URLs
- **AND** pagination SHALL advance according to the site's next-page link

#### Scenario: The latest route has finite results

- **WHEN** the user reaches the end of MangaPill's latest manga listing
- **THEN** the source SHALL report no next page rather than request a duplicate page

### Requirement: MangaPill SHALL expose details and ordered chapter pages

The source SHALL parse series metadata and chapter links from the series page, and chapter image URLs from their actual lazy-load attributes in reading order.

#### Scenario: A manga chapter is opened

- **WHEN** chapter content is requested
- **THEN** the source SHALL return `.pages(imageURLs:)` with the first printed page first

#### Scenario: Required chapter markup is absent

- **WHEN** the page has no chapter image elements
- **THEN** the source SHALL throw a contextual parsing error rather than return an empty chapter

### Requirement: MangaPill images SHALL load online

MangaPill cover and page image requests, including prefetches, SHALL include the site's required referer without adding that header to unrelated image hosts.

#### Scenario: A MangaPill page image is fetched

- **WHEN** the reader or its prefetcher requests an image from the MangaPill CDN
- **THEN** the request SHALL include the MangaPill referer

