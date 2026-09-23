# Codemap: `ReadrTests/`

Swift Testing (`import Testing`), one suite per type under test.

| Path | Contents |
| --- | --- |
| `Core/` | `stableHash64` and `computeSourceID` guard rails, the metadata cache, cache keys, and the catalog pager |
| `Domain/` | Model identity, content shapes, catalog paging values, filters, and the detail merge |
| `Data/` | `SourceRegistry`, entity keys, mappers, the library repository, settings, store survival, the HTTP client, `HTMLSource`, and the catalog repository |
| `Sources/` | Fixture-driven tests for FreeWebNovel and AsuraScans |
| `UI/` | Route/navigation identity plus Library and Browse presentation-model behavior |
| `Support/` | `StubSource`, `StubURLProtocol`, and the bundled fixture loader |
| `Fixtures/<sitename>/` | Saved real-markup captures or hand-reduced extracts of observed real markup, one directory per source |

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

`StubURLProtocol` answers from a registered table and records what was requested.
Recording is what makes the negative assertions possible: a cache hit is proved by
a request that did *not* happen, and the concurrency bound by a peak that was
never exceeded. A URL nothing registered answers 599 rather than an empty body, so
a test that forgot a stub fails loudly instead of looking like a parse failure.

Suites that use it are `.serialized` — `URLProtocol` is instantiated by the
loading system, so the registry has to be reachable statically.

`HTMLSourceTests` drives a test-only subclass over hand-written markup rather than
a real plugin. It tests the base type, and a real site's selectors would make it
fail whenever that site changed, for reasons that have nothing to do with the code
under test. Real fixtures belong to the plugin suites in `Fixtures/<sitename>/`.

One test in it asserts that parsing did not run on the main actor. Nothing fails
if that regresses — the UI just stutters — so it is the only thing that would
catch it.
