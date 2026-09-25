## Why

The series screen's Continue Reading button keeps sending the reader back to the
first chapter they left unfinished. It does this even after they have read
several later chapters to the end. The reader expects Continue to open the
chapter they were reading last. It also must not jump to an old chapter they
opened by mistake.

## What Changes

- Continue Reading opens the chapter the reader read most recently. If that
  chapter is unfinished, it opens that chapter where they stopped. If it is
  finished, it opens the next unread chapter after it.
- Opening a chapter no longer counts as reading it. A chapter becomes the one
  Continue follows only after the reader has read at least 5% of it (the
  Reader's existing save step) or has reached its end. Opening a chapter and
  backing out, or flipping a page or two, leaves Continue where it was.
- Opening a chapter still counts as reading the *series*, so the Library's Last
  Read sort behaves as it does today.
- The button's label and the chapter list look the same. Each chapter keeps its
  own saved position.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `unified-reader-screen`: reading progress is recorded only once the reader
  engages with a chapter. Continue Reading resumes the chapter read most
  recently.

## Impact

- **Domain:** `ChapterReadingOrder.continueTarget` selects by recency. The
  library and chapter repositories gain a call that stamps only the series as
  opened.
- **Data:** `SwiftDataLibraryRepository` implements it, and
  `ObservedLibraryRepository` forwards it. The schema does not change.
- **UI:** `ReaderModel` records an open separately from progress, and records
  progress only after the reader engages with the chapter.
- **Tests:** reading-order, reader-model, and repository tests. Test fakes gain
  the new call.

## Non-goals

- Changing the Continue button's label or showing which chapter it opens.
- Changing how manually marking chapters read or unread works.
- Undo for progress changes.
