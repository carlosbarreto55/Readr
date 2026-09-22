# Source contract

- The `Source` protocol is stable. Changing it requires explicit human approval.
- `HTMLSource` is the base type for HTML sites. Keep it site-agnostic.
- `SourceRegistry` is a static `[Int64: any Source]` built by the composition
  root. No dynamic loading.
- Source IDs come from `computeSourceID(name:lang:type:)`. Never hand-pick one.
- `computeSourceID` uses an explicitly stable hash (FNV-1a 64 or truncated
  SHA-256). **Never `Hasher`** — it is seeded per process and would orphan the
  entire library on every launch. See `architecture.md` §4.1.
- Sources throw on error. They do not log, do not catch, do not return `nil`
  sentinels.
