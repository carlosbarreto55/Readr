# Codemap: `Background/`

> **No implementation yet.**

`BGTaskScheduler` entry points. Identifiers are declared in `project.yml` under
`BGTaskSchedulerPermittedIdentifiers`.

| Identifier | Type | Purpose |
| --- | --- | --- |
| `dev.opus.readr.refresh.library` | `BGAppRefreshTask` | Opportunistic library refresh |
| `dev.opus.readr.process.downloads` | `BGProcessingTask` | Download queue bookkeeping |

Background execution on iOS is best-effort: the system decides whether a task
runs at all. **No feature may assume a background task ran.** The foreground
refresh on app activation is the actual guarantee. `architecture.md` §8 records
this as an accepted limitation relative to the Android app Readr descends from.

Background `URLSession` transfers are the exception — those do survive suspension.
