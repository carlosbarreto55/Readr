# Codemap: `Background/`

> **Implemented in M8.**

`BGTaskScheduler` entry points. Identifiers are declared in `project.yml` under
`BGTaskSchedulerPermittedIdentifiers`.

| File | Responsibility |
| --- | --- |
| `BackgroundTasks.swift` | Registers both handlers (from `ReadrApp.init`, before launch completes) and schedules both requests when the app enters the background. |

| Identifier | Type | Purpose |
| --- | --- | --- |
| `dev.opus.readr.refresh.library` | `BGAppRefreshTask` | Opportunistic library refresh (chapter merge and blank-title repair); reschedules itself |
| `dev.opus.readr.process.downloads` | `BGProcessingTask` | Drains the download queue; requested only when something is queued |

Each handler runs its work in a task cancelled by the expiration handler. A
download cut off by expiration returns to pending.

Background execution on iOS is best-effort: the system decides whether a task
runs at all. **No feature may assume a background task ran.** The foreground
refresh on app activation is the library's actual guarantee, and the download
queue resumes at every launch. `architecture.md` §8 records this as an accepted
limitation relative to the Android app Readr descends from.
