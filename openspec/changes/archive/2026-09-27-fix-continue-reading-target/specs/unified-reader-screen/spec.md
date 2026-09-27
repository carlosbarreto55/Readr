## MODIFIED Requirements

### Requirement: Reading progress SHALL be recorded

Progress MUST be persisted per chapter as the user reads, and a chapter MUST be
marked read on completion. Opening a chapter MUST NOT, by itself, count as
reading it: a chapter's progress and last-read time MUST NOT change until the
user has moved at least 5% of the chapter away from where it opened, or has
reached its end. Opening a chapter MUST still mark its series as read now.

#### Scenario: The user reads partway

- **WHEN** the user scrolls or pages partway through a chapter and leaves
- **THEN** the position SHALL be persisted
- **AND** reopening the chapter SHALL restore it

#### Scenario: The user reaches the end

- **WHEN** the user reaches the end of a chapter
- **THEN** it SHALL be marked read

#### Scenario: The user opens a chapter and backs out

- **WHEN** the user opens a chapter and leaves having moved less than 5% of it
- **THEN** the chapter's position, read state, and last-read time SHALL be
  unchanged
- **AND** the series SHALL be stamped as read now for the Library's Last Read
  sort

## ADDED Requirements

### Requirement: Continue Reading SHALL resume the chapter read most recently

The series screen's Continue Reading action MUST open the chapter the user read
most recently, meaning the chapter with the latest last-read time among
chapters that are read or partly read. If that chapter is partly read, Continue
MUST open it. If it is read, Continue MUST open the first unread chapter after
it, or the last chapter when none after it is unread. When no chapter has a
last-read time, Continue MUST open the first unread chapter after the last read
chapter, or the first chapter when none is read.

#### Scenario: The user leaves a chapter unfinished and reads on

- **WHEN** the user leaves chapter 1 partly read and then reads chapters 2 to 5
  to the end
- **THEN** Continue Reading SHALL open chapter 6

#### Scenario: The user stops partway through the latest chapter

- **WHEN** the chapter read most recently is partly read
- **THEN** Continue Reading SHALL open that chapter at its saved position

#### Scenario: The user opens an old chapter by mistake

- **WHEN** the user is partway through chapter 20, opens chapter 3, and leaves
  having moved less than 5% of it
- **THEN** Continue Reading SHALL still open chapter 20

#### Scenario: The user rereads an unfinished older chapter

- **WHEN** the user reads further into an older chapter that is partly read
- **THEN** Continue Reading SHALL open that older chapter

#### Scenario: Nothing carries a last-read time

- **WHEN** chapters were only marked read from the chapter list
- **THEN** Continue Reading SHALL open the first unread chapter after the last
  read chapter
