# Codemap: `ReadrTests/`

> **No tests yet.** The target exists and builds so the verification lane is real
> from day one.

| Path | Contents |
| --- | --- |
| `Fixtures/<sitename>/` | Saved HTML captured from real pages, one directory per source |

Testing approach:

| Under test | Approach |
| --- | --- |
| Source plugins | Saved fixtures served through a stubbed `URLProtocol` — never live network |
| Repositories and models | Hand-rolled fakes of the `Domain/` protocols |
| SwiftData migrations | Open a store written by the previous schema, assert data survived |
| `computeSourceID` | Hardcoded expected value for a known input |

The `computeSourceID` test is a guard rail, not a characterization test. If it
fails, the hash changed and every persisted library would be orphaned — fix the
code, never the expectation.
