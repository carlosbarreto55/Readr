# download-progress-reporting

## Purpose

Defines what download progress the UI observes, so queue state is legible without
polling.

## Requirements

### Requirement: Queue state SHALL be observable

The download repository MUST expose queue state as an observable stream that
updates as entries change.

#### Scenario: An entry changes state

- **WHEN** an entry moves between pending, downloading, completed, and failed
- **THEN** observers SHALL receive the updated state
- **AND** the UI SHALL NOT poll

#### Scenario: The Downloads screen is open

- **WHEN** entries progress while the screen is visible
- **THEN** the displayed state SHALL update without user interaction

### Requirement: Progress SHALL be reported for the active entry

The entry being downloaded MUST report fractional progress where total size is
known, and indeterminate progress where it is not.

#### Scenario: Total size is known

- **WHEN** a download reports a known expected size
- **THEN** progress SHALL be reported as a fraction between 0 and 1

#### Scenario: Total size is unknown

- **WHEN** expected size is unavailable
- **THEN** progress SHALL be reported as indeterminate rather than as zero

#### Scenario: A page-based chapter downloads

- **WHEN** a chapter of many images downloads
- **THEN** progress SHALL reflect completed pages against total pages

### Requirement: Failures SHALL be visible and actionable

A failed entry MUST remain visible with a retry action rather than disappearing.

#### Scenario: An entry fails

- **WHEN** a download fails
- **THEN** it SHALL remain listed in a failed state
- **AND** a retry action SHALL return it to pending

#### Scenario: The user cancels an entry

- **WHEN** the user cancels a pending or downloading entry
- **THEN** it SHALL be removed from the queue
- **AND** any partial payload SHALL be deleted
