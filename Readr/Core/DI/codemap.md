# Codemap: `Core/DI/`

The composition root. Readr uses no DI framework — see `architecture.md` §7.1.

| File | Responsibility |
| --- | --- |
| `AppContainer.swift` | Owns `URLSession` and `SourceRegistry`, plus the SwiftUI environment entry that carries it. Built once in `ReadrApp`. |
| `SourceRegistration.swift` | `liveSources()` — the one place that imports concrete site types. Currently returns nothing; the first plugin registers here. |

`AppContainer` is `Sendable` rather than main-actor-bound, because background
tasks reuse the same graph outside the UI lifecycle. The `ModelContainer` and the
repositories join it with the persistence layer.

Only `ReadrApp` constructs an `AppContainer`. Views never construct dependencies;
presentation models receive them through `init`.
