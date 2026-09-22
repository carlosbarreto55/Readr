# source-metadata-cache

## Purpose

Defines caching of source responses so repeat browsing does not re-fetch
unchanged remote data.

## Requirements

### Requirement: Source responses SHALL be cached with an explicit lifetime

Catalog and detail responses MUST be cached in memory keyed by their request, and
each entry MUST carry an expiry.

#### Scenario: The same catalog page is requested twice

- **WHEN** a catalog page is requested again within its cache lifetime
- **THEN** the cached page SHALL be returned
- **AND** no network request SHALL be issued

#### Scenario: A cached entry expires

- **WHEN** a cached entry is requested after its expiry
- **THEN** it SHALL be discarded and the request SHALL go to the network

### Requirement: Explicit refresh SHALL bypass the cache

A user-initiated refresh MUST ignore cached entries and re-fetch.

#### Scenario: The user pulls to refresh

- **WHEN** the user triggers a refresh on a catalog or series
- **THEN** the request SHALL bypass the cache
- **AND** the fresh response SHALL replace the cached entry

### Requirement: The cache SHALL be bounded

The cache MUST have a fixed maximum entry count and MUST evict least-recently-used
entries beyond it.

#### Scenario: The cache is full

- **WHEN** a new entry is stored and the cache is at capacity
- **THEN** the least recently used entry SHALL be evicted

#### Scenario: The app is backgrounded under memory pressure

- **WHEN** the system issues a memory warning
- **THEN** the cache SHALL be cleared
- **AND** no persisted user data SHALL be affected
