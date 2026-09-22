# source-request-performance

## Purpose

Constrains outbound request behavior so the app stays responsive and does not
overload the sites it reads from.

## Requirements

### Requirement: Concurrent requests to one source SHALL be bounded

The app MUST NOT issue more than a fixed maximum number of concurrent requests to
a single source.

#### Scenario: A chapter of many images loads

- **WHEN** an image-page chapter requires many image requests
- **THEN** concurrency against that host SHALL stay within the configured maximum

#### Scenario: Two catalogs load at once

- **WHEN** requests to two different sources are in flight
- **THEN** each source's limit SHALL apply independently

### Requirement: Requests SHALL time out

Every request MUST carry a finite timeout and MUST surface a retryable error when
it elapses.

#### Scenario: A host stops responding

- **WHEN** a request exceeds its timeout
- **THEN** it SHALL fail with a retryable error
- **AND** the UI SHALL NOT remain in a loading state indefinitely

### Requirement: Parsing SHALL NOT block the main actor

HTML parsing and image decoding MUST occur off the main actor.

#### Scenario: A large chapter is parsed

- **WHEN** a chapter document is parsed
- **THEN** parsing SHALL run off the main actor
- **AND** the UI SHALL remain responsive throughout
