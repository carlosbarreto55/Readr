# Codemap: `Data/Repository/`

Repository implementations. These coordinate `SourceRegistry`, SwiftData,
the filesystem, and Spotlight — and they are the only layer permitted to.

| File | Responsibility |
| --- | --- |
| `SwiftDataLibraryRepository.swift` | `LibraryRepository` over SwiftData: saved items with reader-owned timestamps and their chapter state. |
| `DefaultCatalogRepository.swift` | `CatalogRepository` over `SourceRegistry`, with the metadata caches in front of it, and a bounded memory of listed series. |
| `DefaultChapterRepository.swift` | `ChapterRepository` over the library, catalog, and downloads: stored chapters for saved series, catalog chapters otherwise; a stored payload before the source unless bypassed; progress only for saved series. |
| `DefaultDownloadRepository.swift` | `DownloadRepository`: a `ModelActor` owning the persisted queue, the single drain loop, the active download, and the snapshot broadcast. Observes library removal to delete a series' downloads. |
| `ChapterDownloader.swift` | Fetches one chapter through the transport and stores it complete via the payload store, reporting page progress. Runs detached from the queue's actor. |
| `DownloadTransport.swift` | The download network seam: content through the catalog, page bytes through the shared `HTTPClient`. |
| `SpotlightProjection.swift` | Library observer that keeps the Spotlight index in step: index on save, delete on removal, rebuild on request; thumbnails fetched afterwards and never for a series removed meanwhile. |
| `DefaultSystemSearchRepository.swift` | `SystemSearchRepository`: resolves a Spotlight result against the library (removing stale entries) and rebuilds the index from it. |
| `ObservedLibraryRepository.swift` | Forwarding `LibraryRepository` decorator that tells `LibraryChangeObserver`s about successful saves and removals. The composition root wraps the store with it. |
| `DefaultSeriesRepository.swift` | `SeriesRepository` over the library and catalog contracts: detail refresh, chapter merge, and the library refresh with blank-title repair. An actor, so two library refreshes never run at once. |

A `@ModelActor`, so every access runs on its own `ModelContext` off the main actor.
Entities never leave it — each method maps to domain values before returning.

Saving a series that is already saved refreshes its metadata and leaves the
reader's own state alone: when it was added, when it was last read, and the
progress recorded against its chapters. Removing one takes its chapters with it
through the relationship's cascade delete rule.

The refresh merge assigns each chapter the position its source listed it at,
marks chapters the source stopped listing, rejects an empty list as a failed
refresh, and rolls the context back if anything throws.

Removal also deletes the series' downloaded payloads, as
`library-browse-catalog` requires: `ObservedLibraryRepository` notifies the
download repository after the store's removal succeeds.

The download queue drains one chapter at a time in enqueue order because there is
one loop. At launch, and from the processing task, `resume()` returns any entry
left downloading to pending. Snapshots are pushed to every observer on every
change; storage usage is recomputed from disk after anything that changes it.

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
