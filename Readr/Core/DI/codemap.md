# Codemap: `Core/DI/`

The composition root. Readr uses no DI framework — see `architecture.md` §7.1.

| File | Responsibility |
| --- | --- |
| `AppContainer.swift` | Owns `URLSession`, the `HTTPClient`, `SourceRegistry`, the `ModelContainer`, the library (wrapped so removal deletes downloads), catalog, series, chapter, and download repositories, and the settings store, plus the SwiftUI environment entry that carries it. Built once in `ReadrApp`. |
| `SourceRegistration.swift` | `liveSources(http:)` — the one place that imports concrete site types. Registers FreeWebNovel and AsuraScans with the shared client. |

`AppContainer` is `Sendable` rather than main-actor-bound, because background
tasks reuse the same graph outside the UI lifecycle.

`live()` throws. A store that cannot be opened is shown to the reader by
`StoreUnavailableView` rather than resolved by deleting it — the store holds their
entire library and every chapter of progress.

The environment entry is `AppContainer?` with no default, on purpose. A container
provided as a convenience would hold an empty library, so a view that missed the
injection would render as though the reader had saved nothing. Absent is legible;
empty is not.

`modelContainer` is `private`. The container reaches every view through the
environment, so a public one would be a supported route from a view to a
`ModelContext` — which `Readr/UI/AGENTS.md` forbids. The store is reachable only
through a repository.

Every source is handed the same `HTTPClient`, so they share one concurrency
budget per host. A source that built its own would get a second full budget and
quietly double what the site sees.

`clearCachesOnMemoryPressure()` registers the memory-warning observer
`source-metadata-cache` requires. It lives here rather than inside the cache so
the cache stays a plain value with no UIKit import and no lifecycle of its own.

Only `ReadrApp` constructs an `AppContainer`. Views never construct dependencies;
presentation models receive them through `init`.
