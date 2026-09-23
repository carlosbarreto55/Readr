## Context

M3 delivered a final-entry-point `HTMLSource`: plugins provide URL builders,
selectors, and extraction while the base type owns fetching, parsing, required
field checks, content-shape dispatch, and detail merging. `liveSources()` is
still empty.

ReaderParser currently ships exactly two source plugins: FreeWebNovel and
AsuraScans. Their implementations and fixtures were inspected at upstream commit
`49ed7cbf277adba16b2ccb3d8589252f8516fe5f`. The FreeWebNovel fixtures are
live-backed captures from 2026-05-27. ReaderParser's AsuraScans fixtures are
explicit placeholders, so they are not treated as selector evidence; the compact
local AsuraScans fixtures instead preserve selector-bearing structures observed
directly on the live browse, home, series, and chapter pages on 2026-09-22. Those
observations are the selector authority; no selector in this change is guessed.

Sequencing: this is M4 of the nine milestones listed in the M1 migration plan.
M5 consumes the registered sources through `CatalogRepository` and does not need
to know either concrete type.

## Goals / Non-Goals

**Goals:**

- Ship one text source and one image-page source through the M3 runtime.
- Preserve the predecessor's source identity tuples and observable parsing.
- Cover every supported source operation using saved HTML and a stubbed
  `URLProtocol`.
- Keep the concrete plugins stateless and site-specific.

**Non-Goals:**

- UI, persistence changes, downloads, Spotlight, or background refresh.
- New source protocol requirements or new dependencies.
- Network-dependent tests or speculative selectors.
- Optional site APIs that duplicate server-rendered HTML already available to
  the shared runtime.

## Decisions

### Port both maintained ReaderParser sources

Although the original milestone label says “first site plugin,” the predecessor
contains two maintained plugins and the M3 proposal/design explicitly reserve M4
for both. Porting both is also the smallest useful exercise of
`ChapterContent`'s two shapes: FreeWebNovel returns text and AsuraScans returns
ordered image URLs.

*Alternative considered — ship only one source.* That would leave one content
shape and half of the template hooks unproven before M5 builds UI on top of them.

### Use the server-rendered HTML paths

FreeWebNovel's detail HTML contains `ul#idData` chapter anchors, and AsuraScans's
chapter HTML contains `div[data-page] img` entries. The Swift plugins use those
real paths through `HTMLSource`.

ReaderParser also attempts a FreeWebNovel AJAX chapter endpoint and an AsuraScans
JSON page endpoint before falling back to HTML. They are optimizations, not
required data paths. Porting them would require a plugin to take over final
`Source` entry points or broaden the shared base around one site's response
shape, weakening the M3 boundary for no capability gain.

*Alternative considered — add site API hooks to `HTMLSource`.* Rejected because
the base must stay site-agnostic and both sources already expose the required
content in HTML.

### Keep source-specific behavior inside each plugin

FreeWebNovel defines its popular/latest/search URLs, listing selector, terminal
pagination selectors, detail extraction, chapter extraction, chapter-number
parsing, and chapter-body cleanup. AsuraScans defines browser-like request
headers, browse/search URLs, a distinct one-page latest layout, details, chapter
dates/numbers, and ordered page extraction.

`HTMLSource` exposes a site-agnostic optional latest-page limit. Its final latest
entry point returns `.empty` before fetching when the requested page exceeds the
limit. AsuraScans sets that limit to one, preventing page two from silently
repeating the homepage; other plugins remain unbounded by default.

Shared helpers remain limited to the existing `Element.absoluteURL` and
`trimmedText` utilities. No site selector or status spelling enters
`HTMLSource`.

### Preserve source identity inputs exactly

The names are `FreeWebNovel` and `AsuraScans`, both use language `en`, and their
types are `.novel` and `.manhwa` respectively. The plugins receive IDs from the
base initializer; each test asserts a hardcoded expected value so an accidental
rename or type change fails before it can orphan stored content.

### Saved fixtures preserve observed real markup

Tests need the markup that determines behavior, not unrelated scripts, ads, and
megabytes of chapter navigation. FreeWebNovel fixtures retain the relevant
structures and representative values from ReaderParser's live-backed captures,
with provenance naming the commit and original fixture. AsuraScans fixtures are
hand-reduced from structures observed directly on named live URLs on 2026-09-22;
their text and content URLs are synthetic stable test data, which each provenance
comment states explicitly. They are served through `StubURLProtocol`; no test
contacts either site.

### Neither plugin advertises remote filters

Both sites support text search, but neither upstream plugin defines a stable
genre/status/sort filter mapping. The inherited `supports(_:) == false` remains
truthful. M5 may still provide local library filtering under the separate
`library-filtering` capability.

## Risks / Trade-offs

- **A site changes markup after the captured fixture** → failures remain loud,
  and selectors/fixtures are updated together from a fresh capture.
- **FreeWebNovel stops server-rendering its complete chapter list** → add a
  source-local request path in a separate OpenSpec change based on an observed
  response; do not guess it into this port.
- **AsuraScans removes image URLs from chapter HTML** → treat the JSON endpoint
  as a new observed requirement and design a site-local implementation without
  weakening the stable `Source` protocol.
- **Relative chapter dates vary with the clock** → tests assert parsed presence
  and ordering-independent bounds, not an exact instant.
- **Cloudflare rejects generic requests** → AsuraScans overrides only the
  existing request-header hook with the proven browser headers.

## Migration Plan

No schema migration is required. Registering the plugins makes them discoverable
to M5 but does not write any data by itself. Rollback removes the two registry
entries and plugin files; existing rows would remain inert under their stable
source IDs until the plugin is restored.

## Open Questions

None. The upstream markup, identity inputs, and HTML fallback paths resolve the
questions deferred from M3.
