## Context

`ChapterReadingOrder.continueTarget` returns the chapter latest in reading order
that is in progress, and ignores when it was read. A chapter left before its end
stays in progress, so it outranks every chapter read to completion after it.
Also, `ReaderModel` writes progress as soon as a chapter loads. That write
stamps the chapter's `lastReadAt`, so recency today also includes chapters the
reader only opened.

## Goals / Non-Goals

**Goals:**
- Continue follows the chapter the reader actually read most recently.
- An accidental open or a stray page flip never moves Continue.
- The Library's Last Read sort keeps counting an open.

**Non-Goals:**
- Schema changes, UI changes, or undo.

## Decisions

**Recency picks the anchor, and read state picks the target.** The anchor is
the engaged chapter (`isRead || readingPosition > 0`) with the latest
`lastReadAt`. Ties go to the chapter later in reading order. If the anchor is in
progress, Continue opens it. If the anchor is read, Continue opens the first
unread chapter after it. A read chapter reopens at its start, so returning the
anchor itself would restart it. The target after it is the reader's frontier.
When nothing is engaged with a timestamp, the old rule applies. That keeps
bulk-marked series, which carry no timestamps, working as before.
*Alternative considered:* a "current chapter" field stored on the series. It
would need a schema migration, and it duplicates what per-chapter `lastReadAt`
already records.

**Opening a chapter stamps the series only.** New
`LibraryRepository.recordOpened(_:at:)` sets `SeriesEntity.lastReadAt`.
`ChapterRepository.recordOpened(in:)` wraps it and returns `ProgressRecording`,
so the Reader still learns whether progress is kept.

**Engagement gate in `ReaderModel`.** The Reader remembers the position a
chapter opened at. It writes nothing for that chapter until the position has
moved at least `persistThreshold` (5%) from there, or the end is reached. After
that, writes behave as today: throttled while scrolling and forced on
close or chapter switch. Reusing the existing threshold keeps one number for
what counts as moving.

## Risks / Trade-offs

- [Series stored before this change have chapters stamped by bare opens] →
  Unread chapters at position 0 are not engaged, so they are ignored. A read
  chapter re-stamped by an old open can still act as the anchor. In that case
  Continue opens the first unread chapter after it, which is usually the
  reader's frontier anyway.
- [Rereading a finished old chapter partway] → Continue opens the first unread
  chapter after it, and does not reopen the finished chapter. This is
  intentional, because a finished chapter restarts from the beginning.
