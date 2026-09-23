## Why

Library and Browse can open a series route, but the destination is still a
placeholder, so a reader can find a series and never see its chapters. M6 makes
the series the place reading starts, and it is the first change that refreshes a
stored chapter list against a live source — which is when the chapter-state
guarantees either hold or quietly fail.

## What Changes

- Replace the pending series destination in Library, Browse, and Downloads with a
  four-file Series screen: cover, title, author/artist, status, genres, synopsis,
  library toggle, a continue-reading action, and the chapter list.
- Show a saved series and its stored chapters immediately and offline, then
  refresh details and chapters from the source; a failed refresh keeps what is
  shown and says so.
- Merge refreshed chapter lists by `(sourceID, url)`: read state and position
  survive, new chapters arrive unread, chapters the source no longer lists are
  kept and marked as no longer listed, and an empty list is treated as a failed
  refresh.
- Give stored chapters a reading order, so "continue" and the chapter list are
  stable whether a source lists newest-first or oldest-first.
- Mark chapters read or unread from the chapter list.
- Add a library refresh — pull-to-refresh in Library and on app activation —
  that repairs saved series whose title is blank and refreshes their chapters.
- Display a readable placeholder derived from the URL anywhere a blank title
  would otherwise render.

## Capabilities

### New Capabilities

None. M6 implements `chapter-refresh-state-preservation` and
`library-blank-title-repair`, which are already normative.

### Modified Capabilities

- `chapter-refresh-state-preservation`: answer the question `LibraryRepository`
  left open — stored chapters carry the position the source listed them at, and
  are presented in reading order.

## Impact

- **Domain:** a stored-chapter value carrying reader state; a reading-order
  function; a display-title rule; a series repository contract that coordinates
  catalog and library; `LibraryRepository` gains the refresh merge and read-state
  writes.
- **Data:** schema v2 adds each chapter's source position and whether the source
  still lists it, with a lightweight migration from v1 and a migration test.
- **UI:** `Readr/UI/Series/` (four files), series destinations in `RootTabView`,
  `.refreshable` on Library, blank-title placeholders on cards.
- **App lifecycle:** a foreground library refresh when the app becomes active.

## Non-goals

- The Reader (M7). Opening a chapter emits the reader route; M7 presents it.
- Downloads and their per-chapter state (M8).
- Spotlight indexing of repaired titles (M9) — the display rule it will use is
  defined here.
- Background library refresh through `BGTaskScheduler`; the foreground refresh is
  the guarantee, and the background task is registered alongside the download
  task in M8.
- Changing the `Source` protocol, identity keys, or relationship delete rules.
