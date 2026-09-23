# Codemap: `Data/Repository/`

Repository implementations. These coordinate `SourceRegistry`, SwiftData,
the filesystem, and Spotlight — and they are the only layer permitted to.

| File | Responsibility |
| --- | --- |
| `SwiftDataLibraryRepository.swift` | `LibraryRepository` over SwiftData: saved items with reader-owned timestamps and their chapter state. |
| `DefaultCatalogRepository.swift` | `CatalogRepository` over `SourceRegistry`, with the metadata caches in front of it. |

A `@ModelActor`, so every access runs on its own `ModelContext` off the main actor.
Entities never leave it — each method maps to domain values before returning.

Saving a series that is already saved refreshes its metadata and leaves the
reader's own state alone: when it was added, when it was last read, and the
progress recorded against its chapters. Removing one takes its chapters with it
through the relationship's cascade delete rule.

Still outstanding: `library-browse-catalog` also requires removal to delete the
series' downloaded payloads. There is no download storage yet; that is wired into
`remove(_:)` when downloads are built.

`DefaultCatalogRepository` is where the decision *whether to fetch* lives —
orchestration, per `architecture.md` §8, so it belongs to a repository rather than
to a source. The practical effect is that a plugin cannot forget to cache and
cannot cache wrongly, because it is never asked to.

Three caches rather than one, with separate lifetimes: catalog pages expire after
five minutes, series details after fifteen minutes, and chapter lists after two
minutes. These lifetimes keep repeat navigation responsive while letting readers
see newly published chapters promptly.

A throw stores nothing. Caching a failure would turn one bad response into several
minutes of a catalog that refuses to load behind a retry button that cannot work.
