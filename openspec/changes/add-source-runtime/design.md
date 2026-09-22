## Context

M1 shipped the `Source` protocol and M2 shipped the store. Between them sits the
runtime that makes a `Source` implementable: HTTP, HTML parsing, caching, paging,
and the orchestration that turns a protocol call into something a screen can use.

Sequencing: this is M3 of the nine milestones listed under Migration Plan in
`openspec/changes/archive/2026-09-22-add-foundation-and-app-shell/design.md`.

Four normative capabilities govern it — `source-listing-pagination`,
`source-detail-parsing`, `source-metadata-cache`, `source-request-performance`.
They are already written; this change implements them and adds no requirement.

The predecessor app, ReaderParser, is the reference for *shape*, not for
behavior. Where it and Readr's specs disagree, the specs win — and they disagree
in one place that matters, recorded under Decisions.

## Goals / Non-Goals

**Goals**

- A plugin author writes selectors and a URL builder. Nothing else.
- Repeat browsing does not re-request; explicit refresh always does.
- The app is bounded in what it does to a site: concurrency, and a timeout on
  every request.
- Nothing parses HTML on the main actor.
- Paging cannot duplicate, drop, or double-request.

**Non-Goals**

- Any concrete source, any screen, any image loading — see the proposal's
  Non-goals.
- A disk cache. The specs ask for an in-memory cache with an expiry; a second
  persistence mechanism alongside SwiftData is not asked for and would need its
  own eviction and migration story.

## Decisions

### `HTMLSource` is a class with template methods — not a protocol with defaults

A plugin subclasses `HTMLSource` and overrides the site-specific parts:
`popularURL(page:)`, `popularSelector`, `series(from:)`, `nextPageSelector`,
`searchURL(query:page:filters:)`, `parseDetails(_:into:)`, `chapterSelector`,
`chapter(from:series:)`, the `latestURL` / selector / extraction hooks, and exactly
one of `parseText(_:)` or `parsePages(_:)`. The `Source` entry points themselves
are final so a plugin cannot bypass the shared request, merge, or shape rules.

A protocol with a default implementation was considered and rejected for one
concrete reason: a default cannot be *required* to be overridden. `parseText` and
`parsePages` are the case that matters — a manhwa source that forgets
`parsePages` must fail, loudly, the first time a chapter opens, and a protocol
extension would instead hand it a silently useless default. As a class method it
throws `SourceError.contentShapeNotImplemented`, which names the bug.

This keeps `architecture.md` §5's framing intact: `HTMLSource` is a convenience,
not the architectural contract. `Source` is still the contract, and a site that
does not fit HTML — a JSON API, say — implements `Source` directly.

### The detail merge lives in `HTMLSource`, not in each plugin

`source-detail-parsing` requires that a field absent from a detail page keeps the
value the catalog listing gave it. That is a rule every plugin would otherwise
have to remember, and forgetting it is invisible: the series still renders, just
with the synopsis blanked out by the refresh that was supposed to improve it.

So `parseDetails(_:into:)` returns what the *page* says, and `HTMLSource` folds
it onto the known series through `Series.enriched(with:)`. A plugin cannot skip
the rule because a plugin never performs the merge.

`enriched(with:)` is a pure function on `Series` in `Readr/Domain/`, so it is
tested without a network, a parser, or a plugin.

**This is where Readr diverges from ReaderParser.** ReaderParser's
`refreshDetails` replaced the series outright, so a detail page that omitted a
cover dropped the cover. Readr's spec forbids that, and the divergence is
deliberate rather than an oversight in the port.

### Identity is preserved by construction

`enriched(with:)` never takes `sourceID` or `url` from the incoming value —
they are not parameters of the merge at all. A detail page that resolves to a
different URL cannot silently become a different series, which is the failure
`source-detail-parsing`'s identity requirement exists to prevent.

### A blank title throws; everything else degrades

`source-detail-parsing` splits fields in two. Optional fields degrade: an
unrecognized status becomes `.unknown`, absent genres become `[]`, and the fetch
succeeds. Required fields fail loudly: no title, or no chapter anchor, throws.

The reason the title is in the second group is that `library-blank-title-repair`
exists as a capability at all — a blank title is a defect ReaderParser shipped and
then needed a repair path for. Throwing at the source is how that defect stops
being created.

### The cache is an actor, keyed by request, bounded and TTL'd

`SourceMetadataCache` holds `maxEntries` values with an expiry, evicting the
least recently used. It is an `actor` rather than a lock-guarded struct: every
caller is already `async`, and an actor makes the check-expiry-then-read sequence
atomic without a lock this codebase would otherwise have to reason about.

Keys are built from the request, and a search key includes the query and a
snapshot of the filter list — length-prefixed, so that two different filter sets
cannot serialize to the same string.

Three caches with separate lifetimes rather than one: catalog pages change often
(5 minutes), series details rarely (15 minutes), chapter lists in between (2
minutes). One shared TTL would either re-fetch details needlessly or serve a
stale chapter list to a reader waiting for a new chapter.

*Alternative considered — `URLCache`.* Free, and it caches at the wrong layer: it
keys on the HTTP request and stores bytes, so every hit still re-parses the
document. The expensive part is parsing, not transfer.

### Memory pressure clears the cache; nothing else is affected

`source-metadata-cache` requires a memory warning to clear the cache. The
observer is registered by the composition root rather than by the cache, so the
cache stays a plain value with no `UIKit` import and no lifecycle of its own.

### Concurrency is bounded per host, not globally

`source-request-performance` requires that each source's limit apply
independently. The bound is therefore held per host by `HTTPClient`, which hands
out permits from a counting semaphore built on continuations — not
`DispatchSemaphore`, which would block a thread and violate invariant 7.

Per host rather than per source ID because the limit protects the *site*, and two
sources on one host share it correctly that way.

### `CatalogPager` owns paging, and holds no view

`source-listing-pagination`'s requirements are a state machine: accumulate in
order, discard an entry whose `(sourceID, url)` is already loaded, refuse a second
request while one is in flight, and clear the in-flight flag on failure so the
same page index can be retried.

It is built here rather than in M5 because it is the capability, and because a
state machine tested through a SwiftUI view is a state machine tested badly. It
takes a `(Int) async throws -> SeriesPage` closure, so it depends on no
repository, no source, and no framework — M5 supplies the closure.

*Alternative considered — leave paging to M5's Browse model.* It would make this
change smaller and leave `source-listing-pagination` unimplemented after the
milestone that claims it, with the dedupe and single-flight rules re-derived
inside a view model where they are hardest to test.

### The catalog repository owns caching, the source does not

A `Source` fetches and parses. Deciding whether to fetch at all is orchestration,
which `architecture.md` §8 puts in a repository. So `CatalogRepository` resolves
the source through the registry, consults the cache, and takes a `refresh` flag
that bypasses it.

That also keeps the cache out of the plugin author's way entirely: a plugin
cannot forget to cache, and cannot cache wrongly.

## Risks / Trade-offs

- **The template-method set is wrong and every plugin fights it** → the set is
  taken from the two plugins M4 actually ports, both of which exist and are read
  as part of this change, rather than imagined.
- **SwiftSoup parsing is synchronous and could land on the main actor** → parsing
  happens inside non-isolated `async` methods, which run on the cooperative pool.
  A test asserts it, because the failure mode is a dropped frame rather than an
  error.
- **A bounded cache holding stale data across a refresh** → refresh does not read
  the cache and overwrites the entry it bypassed, so a refreshed result cannot be
  shadowed by the value it replaced.
- **The concurrency bound deadlocks** → permits are released in a `defer`, and the
  limiter is exercised by a test that saturates it and asserts the peak.
- **`HTMLSource` accumulates site-specific logic** → forbidden by
  `Readr/Sources/AGENTS.md`, and the `reviewer` lane checks it. The pressure will
  come in M4; the rule is written down before it does.

## Migration Plan

No schema change and no stored data. `SchemaV1` is untouched.

Rollback is `git revert`: nothing outside the repository is touched, and with
`liveSources()` still empty, no runtime path reaches any of this code in the
shipped app.

## Open Questions

- Whether `Filter`/`FilterList` need more than the three cases M1 fixed. Carried
  from M1, which deferred it to "M3, where the first real catalog reveals the
  answer" — but the answer needs a real site's filter UI, so it moves to M4 with
  the first plugin, and to M5 where filters are actually selected.
- Whether the three cache lifetimes are right. They are ported from ReaderParser,
  where they were not obviously tuned. Nothing in the specs fixes a number, so
  they are stated in one place and revisited when real browsing exists.
