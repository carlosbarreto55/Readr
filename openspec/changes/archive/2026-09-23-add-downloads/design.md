## Context

M7's `ChapterRepository.content(for:bypassingStored:)` already carries the bypass
flag, and the Reader already performs the one forced re-fetch. Schema v2 stores
series and chapters. `BGTaskScheduler` identifiers and `UIBackgroundModes` were
declared in `project.yml` at M1. `EntityKey.path(for:)` already derives the
filesystem components, guarded by hardcoded tests.

Sequencing: M8 of the nine milestones in the M1 migration plan.

## Goals / Non-Goals

**Goals:**

- A durable, sequential, observable queue.
- Self-contained payloads that read offline and are never half-reported.
- Library removal and explicit deletion free the space they claim to.

**Non-Goals:**

- Background `URLSession`, parallelism, auto-download (see proposal).

## Decisions

### Downloads are their own entity, keyed by chapter identity

Schema v3 adds `DownloadEntity`: the chapter's identity key (unique), source ID,
series and chapter URLs, chapter name and number, series title, content type,
state, error message and retryability, enqueue time, a monotonic sequence number,
and stored byte count. It has **no relationship** to `SeriesEntity` or
`ChapterEntity`: a chapter of an unsaved series can be downloaded, and a chapter
refresh can never touch download state — which is how
`chapter-refresh-state-preservation`'s "download state SHALL be preserved" holds
by construction. Existing identity, keys, and delete rules are unchanged.

v2 → v3 is lightweight (a new entity). v3 reuses v2's unchanged model classes;
the migration test writes a v2 store on disk and reopens it through the plan.

Completed entries stay as the record of what is stored; a queue entry is any
entry not completed.

### Payload store: stage, verify, rename

`ChapterPayloadStore` (Data/Local/Filesystem) writes into a sibling
`<chapterKey>.partial` directory, then writes `manifest.json` (content type and
file names in reading order) and renames the directory into place. A read
succeeds only when the manifest exists and every file it names exists; anything
else reads as not stored. A failed or cancelled download deletes the staging
directory. The store creates `Application Support/Readr/Downloads` with
`isExcludedFromBackup` and re-applies it on every open. It is a `Sendable`
struct whose methods run only on the download repository's actor, never on the
main actor (invariant 7).

Text is stored as `chapter.html`. Pages are `page-0001.<ext>`; a stored manhwa
chapter is served as `.pages(imageURLs:)` of `file://` URLs, which NukeUI loads
like any other URL.

### One repository actor owns the queue

`DefaultDownloadRepository` is a `ModelActor` (its own serial `ModelContext`) that
also holds the payload store, a `DownloadTransport`, and the observers.

- `enqueue` skips chapters with any existing entry except failed ones, which it
  returns to pending — so a re-request never duplicates, and a stored chapter is
  never re-queued. It returns immediately and kicks the drain.
- The drain loop takes the lowest-sequence pending entry, marks it downloading,
  fetches content through the transport, stores every page with progress, commits,
  and marks it completed — or failed with a retryable message. Exactly one entry
  is downloading at a time because one loop exists.
- `resume()` returns any `downloading` entry to `pending` (the app died mid-way)
  and starts the drain. It runs at launch and from the processing task.
- `cancel` removes the entry and its staging directory; if it is the active one,
  the active fetch task is cancelled and the loop moves on.
- Every change publishes a `DownloadQueueSnapshot` — entries in enqueue order,
  the active entry's progress, and storage bytes — to every `updates()` stream,
  which yields the current snapshot immediately. Observers never poll.

Progress: pages report completed/total pages; text, fetched in one request with
no known size, reports indeterminate.

`DownloadTransport` is the network seam: the live one fetches content through
`CatalogRepository.chapterContent(for:)` and image bytes through the shared
`HTTPClient` (so the per-host concurrency bound still applies), sending the
chapter URL as referer. Tests substitute a scripted transport.

### Reading prefers the store

`DefaultChapterRepository.content(for:bypassingStored:)` returns the stored
payload when present and `bypassingStored` is false — no network request is
issued — and the source otherwise.

### Library removal deletes payloads

`AppContainer` wraps the SwiftData library in `ObservedLibraryRepository`, a
forwarding decorator that notifies `LibraryChangeObserver`s after a successful
save or remove. The download repository observes removal and deletes that
series' entries and payload directory. The observer seam is also where M9's
Spotlight projection attaches.

### Background tasks

`Background/BackgroundTasks.swift` registers both identifiers in `ReadrApp.init`,
before launch completes. Entering the background schedules a library refresh
(`BGAppRefreshTask`, earliest in one hour) and, when anything is queued, download
processing (`BGProcessingTask`, requires network). Each handler runs its work in a
task cancelled by the expiration handler and reschedules itself. No feature
depends on either running.

*Alternative considered — background `URLSession`.* Deferred. It needs a
delegate-based session, a stable session identifier, relaunch reconnection, and
per-page task bookkeeping, and the specs require only that the queue survive
relaunch. `architecture.md` §8 is corrected to say what ships.

### Screens

Downloads (four files): queue section (waiting, downloading with determinate or
indeterminate progress, failed with message and Retry; swipe to cancel), stored
chapters grouped by series (swipe to delete; the series header opens the series),
storage used, and Delete All with confirmation. Series: per-chapter download
state, swipe to download/cancel/delete, and a Download All menu. Reader: a
download control in the bottom bar reflecting the current chapter's state.
Settings: storage used and Delete All Downloads.

## Risks / Trade-offs

- **Reusing v2 classes in v3** → proven by the on-disk migration test; if a
  toolchain rejects it, v3 gets frozen copies instead with no data consequence.
- **Downloads only progress while the app runs or a processing task runs** →
  stated; the queue always resumes.
- **A very long manhwa chapter** → pages are fetched sequentially within the
  chapter; the HTTP client's per-host bound keeps the site's view unremarkable.
- **Storage accounting drift** → usage is recomputed from disk after every
  completion and deletion rather than maintained incrementally.

## Migration Plan

Schema v2 → v3, lightweight, adding one entity. No existing row changes. Rollback
is `git revert`; the `Downloads` directory can be deleted by hand without losing
library data.

## Open Questions

None blocking.
