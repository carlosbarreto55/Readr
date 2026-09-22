# Codemap: `Core/Util/`

| File | Responsibility |
| --- | --- |
| `StableHash.swift` | `stableHash64(_:)` — FNV-1a 64 over a string. Deterministic across processes and devices. |
| `ComputeSourceID.swift` | `computeSourceID(name:lang:type:)` — the only way a `sourceID` is produced. |
| `SourceMetadataCache.swift` | Bounded, expiring, LRU in-memory cache of *parsed* source responses. An `actor`; time is injected so expiry is tested by advancing a clock rather than by sleeping. |
| `SourceCacheKey.swift` | The one place a request becomes a cache key. Length-prefixes every variable part, so two different filter sets cannot serialize identically. |
| `CatalogPager.swift` | The paging state machine: append in order, discard an entry already loaded, one request in flight, and a retry that re-requests the same index. Driven by a closure, so it names no repository and no framework. |

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

`SourceMetadataCache` caches parsed values rather than bytes, which is why
`URLCache` would not have served: the expensive part of a catalog page is the
parse, not the transfer. It imports no UIKit and owns no lifecycle — the
memory-warning observer that clears it lives in `Core/DI/`.

`CatalogPager` advances its page index only on success, which is what makes "a
retry re-requests the same page" true by construction rather than by remembering
which page failed.
