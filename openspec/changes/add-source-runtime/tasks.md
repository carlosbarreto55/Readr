## 1. Request layer

All files in this section live in `Readr/Data/Source/`.

- [x] 1.1 `SourceError.swift` — the errors a source throws: a required field that
      could not be parsed, an HTTP status the site returned, a timeout, and the
      content shape a plugin failed to implement. Each carries enough to name the
      site and the URL, because a source that throws is debugged from the message
- [x] 1.2 `HTTPClient.swift` — one `URLSession` request path with a finite
      timeout and a per-host concurrency bound. The bound is a counting semaphore
      built on continuations; **no `DispatchSemaphore`** (invariant 7). Permits
      release in a `defer` so a thrown error cannot leak one. The `defer` lives in
      `HostConcurrencyLimiter.withPermit`, not in the client: `defer` cannot
      `await`, so releasing had to be a synchronous actor-isolated call made from
      inside the actor. Split into its own file for that reason
- [x] 1.3 `ReadrTests/Data/HTTPClientTests.swift` — against a stubbed
      `URLProtocol`: a timeout surfaces as a retryable error; concurrency against
      one host never exceeds the bound under a saturating load; two hosts are
      bounded independently; a 404 throws rather than returning an empty document

## 2. HTML source base type

- [x] 2.1 `HTMLSource.swift` — the base class. Fetch, parse with SwiftSoup, and
      the template methods `design.md` fixes. `chapterContent(for:)` dispatches on
      `type` and throws `contentShapeNotImplemented` if the plugin did not
      override the one its type requires — never a silent empty default
- [x] 2.2 `HTMLSource` performs the detail merge itself: `parseDetails(_:into:)`
      returns what the page says, and the base type folds it on through
      `Series.enriched(with:)`. A plugin never merges, so a plugin cannot forget
- [x] 2.3 A blank or absent title throws. Absent genres, an unrecognized status,
      and every other optional field degrade and the fetch succeeds
- [x] 2.4 `ReadrTests/Data/HTMLSourceTests.swift` — a test-only subclass over
      hand-written fixture HTML: a catalog page parses; `hasMore` follows the
      next-page selector; a missing title throws; an unrecognized status becomes
      `.unknown`; a novel subclass returns `.text` and a manhwa subclass returns
      `.pages`; a subclass that overrode neither throws
- [x] 2.5 `ReadrTests/Data/HTMLSourceTests.swift` also asserts parsing does not
      run on the main actor. The failure mode is a dropped frame, not an error, so
      nothing else would catch it

## 3. Series merge

- [x] 3.1 `Readr/Domain/Model/Series+Enriched.swift` — `enriched(with:)`. Pure,
      framework-free. `sourceID` and `url` are not parameters of the merge, so a
      detail page cannot change which series it is
- [x] 3.2 `ReadrTests/Domain/SeriesEnrichedTests.swift` — a populated field
      replaces; an empty string, an empty array, and a `nil` do not; `.unknown`
      status does not overwrite a known status; identity is unchanged

## 4. Metadata cache

- [x] 4.1 `Readr/Core/Util/SourceMetadataCache.swift` — an `actor`. Bounded by
      entry count, LRU eviction, per-entry expiry, and a `clear()`. Time is
      injected so expiry is tested without sleeping
- [x] 4.2 `Readr/Core/Util/SourceCacheKey.swift` — the one place a request becomes
      a cache key. Search keys are length-prefixed over the query and the filter
      list, so two different filter sets cannot serialize to the same string
- [x] 4.3 `ReadrTests/Core/SourceMetadataCacheTests.swift` — a hit returns without
      the loader running; an expired entry is discarded and re-fetched; the LRU
      entry is evicted at capacity; a read refreshes recency; `clear()` empties it
- [x] 4.4 `ReadrTests/Core/SourceCacheKeyTests.swift` — two filter lists that
      differ produce different keys, including the pair that would collide without
      length prefixing

## 5. Catalog pager

- [x] 5.1 `Readr/Core/Util/CatalogPager.swift` — accumulates pages in order,
      discards an entry whose `(sourceID, url)` is already loaded, refuses a
      second request while one is in flight, and clears the in-flight flag on
      failure so the same page index can be retried. Driven by a closure, so it
      names no repository, no source, and no framework
- [x] 5.2 `ReadrTests/Core/CatalogPagerTests.swift` — page 1 is requested first;
      page N+1 appends after page N; a duplicate entry is discarded rather than
      appended; a load-more during a pending request is ignored and exactly one
      request is in flight; a failure clears the flag and the retry re-requests
      the *same* index; `hasMore == false` stops further requests

## 6. Catalog repository

- [x] 6.1 `Readr/Domain/CatalogRepository.swift` — the protocol. Domain values in
      and out; it names no `Source`, no registry, and no cache, so a presentation
      model that holds one still satisfies invariant 3
- [x] 6.2 `Readr/Data/Repository/DefaultCatalogRepository.swift` — resolves the
      source through `SourceRegistry`, consults the cache, and takes a `refresh`
      flag that bypasses it and replaces the entry it bypassed. An unknown
      `sourceID` throws rather than returning empty
- [x] 6.3 `ReadrTests/Data/CatalogRepositoryTests.swift` — against a fake source
      counting its calls: a second identical request does not reach the source; a
      refresh does, and replaces the cached entry; an expired entry re-fetches; an
      unknown source throws; a failing source propagates rather than swallowing

## 7. Composition

- [x] 7.1 `Readr/Core/DI/AppContainer.swift` — build the `HTTPClient` and the
      catalog repository. Register the memory-warning observer that clears the
      caches, so the cache itself stays free of `UIKit`
- [x] 7.2 `liveSources()` stays empty. This change ships no plugin
- [x] 7.3 Confirm the tabs still show placeholders. This change ships no UI

## 8. Documentation

- [x] 8.1 Update the `codemap.md` of `Readr/Data/Source/`, `Readr/Core/Util/`,
      `Readr/Domain/`, `Readr/Data/Repository/`, `Readr/Core/DI/`, and
      `ReadrTests/`
- [x] 8.2 Update the status banners in `codemap.md`, `AGENTS.md`,
      `architecture.md`, and `README.md`

## 9. Verification

- [x] 9.1 Run the verification sequence — generate, build, test, bundle check,
      lint, format, `openspec validate --all`
- [x] 9.2 Prove invariant 2 mechanically: no `URLSession` outside
      `Readr/Data/Source/` and `Readr/Core/DI/`, and no SwiftSoup import outside
      `Readr/Data/Source/` and `Readr/Sources/`
- [x] 9.3 Prove invariant 7 mechanically: no `DispatchSemaphore` and no `.wait()`
      anywhere under `Readr/`
- [x] 9.4 Run the `reviewer` lane over the diff against the twelve invariants
- [ ] 9.5 `openspec archive add-source-runtime`
