# Codemap: `ReadrTests/`

Swift Testing (`import Testing`), one suite per type under test.

| Path | Contents |
| --- | --- |
| `Core/` | `stableHash64` and `computeSourceID` guard rails |
| `Domain/` | Model identity, content shapes, catalog paging values, filters |
| `Data/` | `SourceRegistry`, entity keys, mappers, the library repository, settings, and store survival |
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

The `computeSourceID`, `stableHash64`, and `EntityKey` tests are guard rails, not
characterization tests. If one fails, a persisted key changed: an orphaned library
in the first two cases, stranded downloaded files in the third. Fix the code, never
the expectation.

`StoreSurvivalTests` writes to a real on-disk store, closes it, and reopens it
through `ReadrMigrationPlan`. There is no migration to test yet; it is the harness
the first one extends, and its doc comment says how.

Repository tests run against an in-memory `ModelContainer`. Settings tests build a
`UserDefaults` suite of their own, so a run leaves nothing behind for the next.
