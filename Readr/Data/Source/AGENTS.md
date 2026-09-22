# Source contract

- The `Source` protocol is stable. Changing it requires explicit human approval.
- `HTMLSource` is the base type for HTML sites. Keep it site-agnostic.
- `SourceRegistry` is a static `[Int64: any Source]` built by the composition
  root. No dynamic loading.
- Source IDs come from `computeSourceID(name:lang:type:)`. Never hand-pick one.
- `computeSourceID` uses an explicitly stable hash (FNV-1a 64 or truncated
  SHA-256) over `"\(name)/\(lang)/\(type.rawValue)"`. **Never `Hasher`** — it is
  seeded per process and would orphan the entire library on every launch. See
  `architecture.md` §4.1.
- A shipped source's `name` and `lang` are **frozen**. They are not display
  strings that happen to be hashed; they are two thirds of the key under which
  that site's library and downloads are stored. Renaming one orphans everything
  belonging to it, silently.
- Every shipped plugin carries a test asserting its own hardcoded `id`. The
  `computeSourceID` test pins the function; only a per-plugin test pins the
  plugin's actual identifier.
- Sources throw on error. They do not log, do not catch, do not return `nil`
  sentinels.
