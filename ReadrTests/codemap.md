# Codemap: `ReadrTests/`

Swift Testing (`import Testing`), one suite per type under test.

| Path | Contents |
| --- | --- |
| `Core/` | `stableHash64` and `computeSourceID` guard rails |
| `Domain/` | Model identity, content shapes, catalog paging values, filters |
| `Data/` | `SourceRegistry` lookup and projection |
| `UI/` | Route identity and per-tab navigation paths |
| `Support/` | `StubSource` — a `Source` that contacts nothing |
| `Fixtures/<sitename>/` | Saved HTML captured from real pages, one directory per source |

Testing approach:

| Under test | Approach |
| --- | --- |
| Source plugins | Saved fixtures served through a stubbed `URLProtocol` — never live network |
| Repositories and models | Hand-rolled fakes of the `Domain/` protocols |
| SwiftData migrations | Open a store written by the previous schema, assert data survived |
| `computeSourceID` | Hardcoded expected value for a known input |

The `computeSourceID` and `stableHash64` tests are guard rails, not
characterization tests. If one fails, the hash changed and every persisted library
would be orphaned — fix the code, never the expectation.
