# Codemap: `Data/Source/`

The plugin boundary. See `AGENTS.md` in this directory for the rules and
`architecture.md` §5 for the model.

| File | Responsibility |
| --- | --- |
| `Source.swift` | The protocol every site implements, plus the `info` projection repositories hand to presentation. Stable — changes need human approval. |
| `SourceRegistry.swift` | `[Int64: any Source]` lookup, populated by `Core/DI/`. Rejects duplicate identifiers at composition time. |

Planned:

| File | Responsibility |
| --- | --- |
| `HTMLSource.swift` | Shared base for HTML sites: request construction, SwiftSoup document fetch, absolute-URL resolution. Site-agnostic. |
| `SourceError.swift` | The error cases sources throw. |

Concrete site implementations live in `Readr/Sources/`, not here.
