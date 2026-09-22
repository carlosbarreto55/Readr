# Codemap: `Core/DI/`

> **No implementation yet.**

The composition root. Readr uses no DI framework — see `architecture.md` §7.1.

Planned contents:

| File | Responsibility |
| --- | --- |
| `AppContainer.swift` | Owns `ModelContainer`, `URLSession`, `SourceRegistry`, and every repository. Built once in `ReadrApp`, read from the SwiftUI environment. |
| `SourceRegistration.swift` | Builds the static `[Int64: any Source]` map. The one place that imports every concrete source. |

Only `ReadrApp` constructs an `AppContainer`. Views never construct dependencies;
presentation models receive them through `init`.
