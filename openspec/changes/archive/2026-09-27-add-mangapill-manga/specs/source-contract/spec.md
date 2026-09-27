## MODIFIED Requirements

### Requirement: A source SHALL implement exactly one content shape

A plugin MUST return `.text(html:)` for novel sources or `.pages(imageURLs:)` for manhwa and manga sources, never both. A plugin that implements neither MUST throw when chapter content is requested; it MUST NOT return an empty or placeholder value.

#### Scenario: A novel source returns content

- **WHEN** a source declaring `ContentType.novel` returns chapter content
- **THEN** it SHALL return `.text(html:)`

#### Scenario: A manhwa source returns content

- **WHEN** a source declaring `ContentType.manhwa` returns chapter content
- **THEN** it SHALL return `.pages(imageURLs:)` in reading order

#### Scenario: A manga source returns content

- **WHEN** a source declaring `ContentType.manga` returns chapter content
- **THEN** it SHALL return `.pages(imageURLs:)` in reading order

#### Scenario: A plugin implements neither content shape

- **WHEN** chapter content is requested from a plugin that implements neither shape
- **THEN** it SHALL throw an error naming the source and the shape its declared `ContentType` requires
- **AND** it SHALL NOT return empty text or an empty page list, because an empty chapter is indistinguishable from a chapter that failed to parse

