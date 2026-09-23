## Why

Offline reading is the reason Readr keeps a library at all, and after M7 every
chapter still needs the network. Library removal also still leaves a documented
gap: `library-browse-catalog` requires a removed series' downloaded payloads to
be deleted, and there has been no download storage to delete from.

## What Changes

- Queue chapters for download from Series detail (one, or every chapter not yet
  downloaded) and from the Reader's chrome; requesting returns immediately and
  never duplicates a queued or stored chapter.
- Drain the queue one chapter at a time in enqueue order; a failure is marked
  retryable and the queue moves on; the queue survives relaunch, and an entry
  interrupted mid-download returns to pending.
- Store each chapter self-contained under
  `Application Support/Readr/Downloads/<sourceID>/<seriesKey>/<chapterKey>/`,
  with every page image local and the `Downloads` directory excluded from backup.
  A chapter with any asset missing is never reported downloaded.
- Serve stored payloads to the Reader in preference to the network, unless the
  Reader's forced re-fetch asks otherwise.
- Replace the Downloads placeholder with the queue (live progress, retry,
  cancel), stored chapters grouped by series, storage used, and delete-all.
- Delete a series' payloads when it is removed from the library; report storage
  usage in Settings.
- Register the two declared `BGTaskScheduler` identifiers: an opportunistic
  library refresh and download-queue processing.

## Capabilities

### New Capabilities

None. M8 implements `download-enqueue`, `download-progress-reporting`, and
`download-offline-reader`.

### Modified Capabilities

- `download-offline-reader`: stored chapters can be deleted individually and all
  at once, and storage usage reflects it.

## Impact

- **Domain:** download entry/state/progress values and a `DownloadRepository`
  contract with an observable queue stream; `ChapterRepository` gains the series
  lookup the Reader needs to label a download.
- **Data:** schema v3 adds a download entity (a lightweight stage, tested on
  disk); a filesystem payload store; `DefaultDownloadRepository`; the library is
  wrapped so removal deletes payloads.
- **UI:** `Readr/UI/Downloads/` (four files); download controls in Series and the
  Reader; storage in Settings; the last placeholder is removed.
- **Background:** `Readr/Background/` registers and schedules both tasks.
- **Docs:** `architecture.md` §8 is corrected to what ships — in-process draining
  resumed by `BGProcessingTask`, not background `URLSession`.

## Non-goals

- Background `URLSession` transfers. The spec requires a queue that survives
  relaunch, not transfers that survive suspension; see design.
- Parallel downloads, download scheduling by network type, or per-series
  auto-download of new chapters.
- Spotlight (M9).
