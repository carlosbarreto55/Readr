# Codemap: `Core/Util/`

> **No implementation yet.**

Planned contents:

| File | Responsibility |
| --- | --- |
| `StableHash.swift` | FNV-1a 64 over a string. Deterministic across processes and devices. |
| `ComputeSourceID.swift` | `computeSourceID(name:lang:type:)` — the only way a `sourceID` is produced. |
| `TitleMatcher.swift` | Normalizes series titles for cross-source comparison. |

`StableHash` exists because Swift's `Hasher` is seeded per process and cannot be
used for anything persisted. `architecture.md` §4.1 explains the failure mode.
The `computeSourceID` test asserts a hardcoded expected value and must never be
updated to match changed output.
