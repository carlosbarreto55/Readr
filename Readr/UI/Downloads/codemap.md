# Codemap: `UI/Downloads/`

> **Implemented in M8.**

Queue state, per-chapter progress, and stored-chapter management.

| File | Responsibility |
| --- | --- |
| `DownloadsScreen.swift` | Reads `AppContainer`, owns `DownloadsModel`, runs its observation while visible, routes to series |
| `DownloadsContent.swift` | Stateless queue (waiting, progress, failed + retry, swipe to cancel), stored chapters grouped by series (swipe to delete), storage used, Delete All with confirmation; owns previews |
| `DownloadsModel.swift` | Follows the repository's snapshot stream — no polling — and forwards row actions |
| `DownloadsState.swift` | Render state, the snapshot grouping, actions, and the open-series effect |

Specs: `download-enqueue`, `download-progress-reporting`,
`download-offline-reader`.
