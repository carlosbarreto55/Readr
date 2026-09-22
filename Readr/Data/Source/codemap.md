# Codemap: `Data/Source/`

> **No implementation yet.**

The plugin boundary. See `AGENTS.md` in this directory for the rules and
`architecture.md` §5 for the model.

Planned contents:

| File | Responsibility |
| --- | --- |
| `Source.swift` | The protocol every site implements. Stable — changes need human approval. |
| `HTMLSource.swift` | Shared base for HTML sites: request construction, SwiftSoup document fetch, absolute-URL resolution. Site-agnostic. |
| `SourceRegistry.swift` | `[Int64: any Source]` lookup, populated by `Core/DI/`. |
| `SourceError.swift` | The error cases sources throw. |

Concrete site implementations live in `Readr/Sources/`, not here.
