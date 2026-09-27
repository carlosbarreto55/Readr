# readcomicsonline-comics-source Specification

## Purpose
Defines how the ReadComicsOnline source discovers western comics (Marvel, DC,
Image), parses series details and issues, and returns every issue page in order.

## Requirements
### Requirement: ReadComicsOnline SHALL expose western comics through catalog and search

The registered ReadComicsOnline source SHALL identify its series as `ContentType.comic`, and it SHALL provide popular, latest, and query search listings from the site's server-rendered series routes.

#### Scenario: A comic listing is requested

- **WHEN** a user browses or searches ReadComicsOnline
- **THEN** the source SHALL return titled comic series with stable source and series URLs
- **AND** each series URL SHALL identify the series and not one of its issues

#### Scenario: A listing has no further pages

- **WHEN** the user reaches the end of a ReadComicsOnline catalog, new-release, or search listing that the site serves as a single page
- **THEN** the source SHALL report no next page rather than request a duplicate page

### Requirement: ReadComicsOnline SHALL expose details and ordered issue pages

The source SHALL parse series metadata and issue links from the series page. It SHALL return every page image URL of an issue in the site's page-number order, including pages that the issue markup does not render as image elements.

#### Scenario: A series is opened

- **WHEN** series details and chapters are requested
- **THEN** the source SHALL return the series title and cover, and one chapter per issue
- **AND** each chapter SHALL carry the issue number shown in its URL when that number is numeric

#### Scenario: A comic issue is opened

- **WHEN** chapter content is requested
- **THEN** the source SHALL return `.pages(imageURLs:)` with page 1 first and one URL per page of the issue

#### Scenario: Required issue page data is absent

- **WHEN** the issue page contains no page list
- **THEN** the source SHALL throw a contextual parsing error rather than return an empty chapter

### Requirement: ReadComicsOnline images SHALL load online without source-specific headers

ReadComicsOnline cover and page images SHALL load, including through prefetch, with the app's default image requests. No referer or cookie rule SHALL be added for its image host.

#### Scenario: A ReadComicsOnline page image is fetched

- **WHEN** the reader or its prefetcher requests an image from the ReadComicsOnline CDN
- **THEN** the image SHALL load using the default image request

