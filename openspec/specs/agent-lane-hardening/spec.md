# agent-lane-hardening

## Purpose

Constrains what each specialized agent lane may do, so that a lane cannot quietly
exceed its remit or produce work that violates an architectural invariant.

## Requirements

### Requirement: Each lane SHALL own a bounded scope

Every agent definition in `.claude/agents/` MUST declare what it owns, which
rules file it reads, and which paths it may write. A lane MUST NOT write outside
its declared paths.

#### Scenario: A lane is asked to work outside its scope

- **WHEN** a lane receives a task whose files fall outside its declared paths
- **THEN** it SHALL decline and name the lane that owns those paths
- **AND** it SHALL NOT edit the out-of-scope files

#### Scenario: A task spans two lanes

- **WHEN** work requires changes owned by two different lanes
- **THEN** the orchestrator SHALL split the work rather than widening one lane

### Requirement: The reviewer lane SHALL be read-only

The `reviewer` lane MUST NOT write, edit, or delete any file. It reports findings
only.

#### Scenario: Reviewer finds a defect

- **WHEN** `reviewer` identifies a violation of an `architecture.md` invariant
- **THEN** it SHALL report the file, the invariant, and the reason
- **AND** it SHALL NOT apply a fix

### Requirement: Source authors MUST NOT invent selectors

The `source-author` lane MUST NOT guess CSS selectors, URL patterns, or response
shapes for a site whose real markup it has not been given.

#### Scenario: Markup is unavailable

- **WHEN** `source-author` is asked to add a source without fixtures or sample
  markup
- **THEN** it SHALL scaffold the plugin, registration, and fixture directory
- **AND** it SHALL leave selectors unimplemented and say so explicitly

#### Scenario: A guessed selector would pass compilation

- **WHEN** a plausible-looking selector would compile but is unverified
- **THEN** it SHALL NOT be written, because a wrong selector fails silently at
  runtime rather than at build time

### Requirement: Approval gates SHALL be honored by every lane

A lane MUST NOT proceed past an approval gate listed in `AGENTS.md` without
explicit human approval, regardless of how routine the surrounding task is.

#### Scenario: A change touches the Source protocol

- **WHEN** any lane determines that completing a task requires changing the
  `Source` protocol
- **THEN** it SHALL stop and request approval before editing
