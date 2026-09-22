## Why

Readr can remember a series but cannot fetch one. `Source` is a protocol with no
implementation and no machinery behind it: nothing issues a request, nothing
parses HTML, nothing caches a response, and nothing bounds what the app does to a
site it reads from.

Writing that machinery into the first plugin would put it in the wrong place.
Every site needs the same fetch-parse-throw skeleton, the same timeout, the same
concurrency bound, and the same "details enrich, they do not replace" rule — and
a rule that lives in a plugin is a rule the second plugin gets wrong. This change
builds the runtime first so that M4's plugin is selectors and nothing else.

## What Changes

- An HTML site can be implemented by writing selectors. Fetching, parsing,
  paging, and the merge of detail data onto catalog data are handled once.
- Browsing the same catalog page twice within a few minutes does not hit the
  network twice, and a pull-to-refresh ignores what was cached.
- The app cannot flood a site: requests to one source are bounded, each source is
  bounded independently, and every request times out rather than hanging.
- Parsing happens off the main actor, so a large chapter cannot freeze the UI.
- A catalog pages forward without duplicating entries, without dropping them, and
  without issuing a second request while the first is still in flight.
- Detail fetches enrich a series rather than overwriting it: a field the detail
  page omits keeps the value the catalog listing gave it.
- A series whose title cannot be parsed fails loudly instead of being stored
  blank.

Nothing is visible on screen yet. There is still no plugin and no catalog UI —
this change is proved by tests driving a stubbed `URLProtocol`.

## Capabilities

### New Capabilities

None. The four capabilities this change exists to implement —
`source-listing-pagination`, `source-detail-parsing`, `source-metadata-cache`,
`source-request-performance` — are already normative and are implemented as
written, with no requirement changed.

### Modified Capabilities

- `source-contract`: two gaps that only become reachable once a shared base type
  exists. The content-shape requirement covered a novel source and a manhwa
  source but not a plugin that implements *neither* — the failure `HTMLSource`
  makes possible for the first time. And the rules governing a shared base type
  lived only in `Readr/Sources/AGENTS.md`: that it stays site-agnostic, and that
  a rule every plugin must follow is enforced by the base type rather than
  repeated in each plugin.

## Impact

- **New code**: `Readr/Data/Source/` gains the HTTP client, the `HTMLSource` base
  type, and the source error type. `Readr/Core/Util/` gains the bounded TTL cache
  and the catalog pager. `Readr/Domain/` gains the catalog repository protocol and
  the series merge. `Readr/Data/Repository/` gains its implementation.
- **Changed**: `Readr/Core/DI/AppContainer.swift` gains the HTTP client and the
  catalog repository.
- **New tests**: fetch and parse against a stubbed `URLProtocol`, cache expiry and
  eviction, pager dedupe and single-flight, merge preservation, concurrency bound,
  timeout, and an assertion that parsing does not run on the main actor.
- **Dependencies**: SwiftSoup is imported for the first time. It is already
  declared in `project.yml`; no new dependency is added.
- **Risk**: `HTMLSource`'s template methods fix what a plugin has to supply.
  Getting that set wrong makes every later plugin awkward, which is why the set
  is derived from the two real plugins being ported in M4 rather than guessed.

## Non-goals

- Any site plugin. M4 ports the first two; this change ships zero concrete
  sources and `liveSources()` stays empty.
- Any screen. The tabs keep their placeholders.
- Image loading and decoding. Nuke stays unimported until the reader needs it.
- Persisting catalog results. Browse results are not library membership — only a
  series the reader saves is stored, and that is already built.
- Downloads, Spotlight, background refresh.
