## ADDED Requirements

### Requirement: The live registry SHALL expose both initial sources

The live app SHALL register FreeWebNovel and AsuraScans with the shared HTTP
runtime, and repository source discovery SHALL expose both as domain metadata.

#### Scenario: Sources are discovered

- **WHEN** the live source registry is projected through the catalog repository
- **THEN** it SHALL contain `FreeWebNovel` as an English novel source
- **AND** it SHALL contain `AsuraScans` as an English manhwa source

#### Scenario: Source identities are stable

- **WHEN** either initial plugin is instantiated
- **THEN** its identifier SHALL equal the recorded identifier for its fixed name,
  language, and content type

### Requirement: FreeWebNovel SHALL provide readable novel data

FreeWebNovel SHALL parse the site's popular and latest catalogs, text search,
series details, chapter list, and chapter body from the observed HTML markup.

#### Scenario: A popular catalog is requested

- **WHEN** a valid FreeWebNovel popular-listing page is fetched
- **THEN** its series SHALL be returned in source order with absolute series and
  cover URLs
- **AND** the single-page listing SHALL report no next page

#### Scenario: A latest catalog is requested

- **WHEN** a valid FreeWebNovel latest-listing page contains a usable next-page
  link
- **THEN** its series SHALL be returned in source order
- **AND** the page SHALL report that more results exist

#### Scenario: A novel is opened

- **WHEN** valid detail and chapter-list markup is fetched for a FreeWebNovel
  series
- **THEN** the source SHALL parse its title, cover, author, synopsis, genres, and
  status
- **AND** it SHALL return chapter names, numbers, and absolute URLs in source
  order

#### Scenario: A novel chapter is read

- **WHEN** a FreeWebNovel chapter contains an article body plus known ad,
  script, and watermark nodes
- **THEN** the source SHALL return `.text(html:)` containing the reading content
- **AND** the returned HTML SHALL exclude those non-reading nodes

### Requirement: AsuraScans SHALL provide readable manhwa data

AsuraScans SHALL parse the site's browse and latest catalogs, text search,
series details, chapter list, and chapter images from the observed HTML markup.

#### Scenario: A browse catalog is requested

- **WHEN** a valid AsuraScans browse page is fetched
- **THEN** its series SHALL be returned in source order with title, status, and
  absolute series and cover URLs
- **AND** an enabled next-page control SHALL report that more results exist

#### Scenario: Latest updates are requested

- **WHEN** the AsuraScans homepage contains latest-update rows
- **THEN** those series SHALL be returned from the latest operation
- **AND** the one-page result SHALL report no next page

#### Scenario: A later latest page is requested

- **WHEN** latest updates page two is requested from the one-page AsuraScans feed
- **THEN** the source SHALL return an empty terminal page
- **AND** it SHALL NOT repeat the homepage network request

#### Scenario: A manhwa is opened

- **WHEN** valid detail and chapter-list markup is fetched for an AsuraScans
  series
- **THEN** the source SHALL parse its title, cover, author, artist, synopsis,
  genres, and status
- **AND** it SHALL return chapter names, numbers, dates where recognized, and
  absolute URLs in source order

#### Scenario: A manhwa chapter is read

- **WHEN** an AsuraScans chapter contains ordered page-image elements
- **THEN** the source SHALL return `.pages(imageURLs:)`
- **AND** every absolute image URL SHALL preserve document order

### Requirement: Initial source parsing SHALL fail loudly on malformed required data

The initial plugins SHALL propagate request and parse failures and SHALL NOT
substitute empty required values for malformed source markup.

#### Scenario: A required series link is absent

- **WHEN** a matched source card has no valid series URL
- **THEN** the source SHALL throw an error naming the missing required field and
  request URL

#### Scenario: Required chapter content is absent

- **WHEN** a novel has no article body or a manhwa has no page images
- **THEN** the source SHALL throw
- **AND** it SHALL NOT return empty text or an empty page list
