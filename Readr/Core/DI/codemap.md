# Codemap: `Core/DI/`

The composition root. Readr uses no DI framework — see `architecture.md` §7.1.

| File | Responsibility |
| --- | --- |
| `AppContainer.swift` | Owns `URLSession`, `SourceRegistry`, the `ModelContainer`, the library repository, and the settings store, plus the SwiftUI environment entry that carries it. Built once in `ReadrApp`. |
| `SourceRegistration.swift` | `liveSources()` — the one place that imports concrete site types. Currently returns nothing; the first plugin registers here. |

`AppContainer` is `Sendable` rather than main-actor-bound, because background
tasks reuse the same graph outside the UI lifecycle.

`live()` throws. A store that cannot be opened is shown to the reader by
`StoreUnavailableView` rather than resolved by deleting it — the store holds their
entire library and every chapter of progress.

The environment entry is `AppContainer?` with no default, on purpose. A container
provided as a convenience would hold an empty library, so a view that missed the
injection would render as though the reader had saved nothing. Absent is legible;
empty is not.

Only `ReadrApp` constructs an `AppContainer`. Views never construct dependencies;
presentation models receive them through `init`.
