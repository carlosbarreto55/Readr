# download-enqueue

## Purpose

Defines how chapters are queued for offline reading and how the queue is drained.

## Requirements

### Requirement: Chapters SHALL be enqueued rather than downloaded inline

Requesting a download MUST add a queue entry and return immediately.

#### Scenario: A single chapter is requested

- **WHEN** the user requests a chapter download
- **THEN** a queue entry SHALL be created in a pending state
- **AND** the UI SHALL remain responsive

#### Scenario: A whole series is requested

- **WHEN** the user requests all undownloaded chapters of a series
- **THEN** one queue entry SHALL be created per chapter

#### Scenario: An already-queued chapter is requested again

- **WHEN** a chapter that is pending or downloading is requested again
- **THEN** no duplicate entry SHALL be created

#### Scenario: An already-downloaded chapter is requested

- **WHEN** a chapter already stored locally is requested
- **THEN** no queue entry SHALL be created

### Requirement: The queue SHALL be drained sequentially

Entries MUST be processed one at a time in enqueue order.

#### Scenario: Several chapters are queued

- **WHEN** multiple entries are pending
- **THEN** they SHALL be processed in the order enqueued
- **AND** exactly one SHALL be in the downloading state at a time

#### Scenario: An entry fails

- **WHEN** a download throws
- **THEN** that entry SHALL be marked failed with a retryable error
- **AND** the queue SHALL continue with the next entry

### Requirement: The queue SHALL survive relaunch

Queue state MUST be persisted, and interrupted work MUST resume rather than be
lost.

#### Scenario: The app is terminated mid-queue

- **WHEN** the app is terminated with entries pending
- **THEN** those entries SHALL still be pending on next launch
- **AND** draining SHALL resume

#### Scenario: An entry was mid-download at termination

- **WHEN** an entry was downloading when the app terminated
- **THEN** it SHALL be returned to pending rather than left as downloading
