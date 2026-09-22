# Codemap: `Core/Util/`

| File | Responsibility |
| --- | --- |
| `StableHash.swift` | `stableHash64(_:)` — FNV-1a 64 over a string. Deterministic across processes and devices. |
| `ComputeSourceID.swift` | `computeSourceID(name:lang:type:)` — the only way a `sourceID` is produced. |

Planned:

| File | Responsibility |
| --- | --- |
| `TitleMatcher.swift` | Normalizes series titles for cross-source comparison. |

`StableHash` exists because Swift's `Hasher` is seeded per process and cannot be
used for anything persisted. `architecture.md` §4.1 explains the failure mode.

`computeSourceID` hashes `ContentType.rawValue`, never the case name, so renaming
a case cannot re-key stored data. Both functions are covered by tests asserting
hardcoded expected values; those expectations are guard rails and are never
updated to match changed output.
