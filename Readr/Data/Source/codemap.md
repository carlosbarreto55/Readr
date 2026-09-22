# Codemap: `Data/Source/`

The plugin boundary and the runtime behind it. See `AGENTS.md` in this directory
for the rules and `architecture.md` §5 for the model.

| File | Responsibility |
| --- | --- |
| `Source.swift` | The protocol every site implements, plus the `info` projection repositories hand to presentation. Stable — changes need human approval. |
| `SourceRegistry.swift` | `[Int64: any Source]` lookup, populated by `Core/DI/`. Rejects duplicate identifiers at composition time. |
| `SourceError.swift` | What a source throws. Carries the site name and URL, and answers `isRetryable` so a surface only offers a retry that could work. |
| `HTTPClient.swift` | The one outbound request path: a finite timeout, a per-host concurrency bound, and charset-aware decoding. Returns text, not a document, so a future JSON source can use it. |
| `HostConcurrencyLimiter.swift` | The bound itself, per host, built on continuations. Never `DispatchSemaphore` — see invariant 7. |
| `HTMLSource.swift` | Shared base for HTML sites. Fetches, parses with SwiftSoup off the main actor, performs the detail merge, and dispatches chapter content on `ContentType`. Site-agnostic. |

Concrete site implementations live in `Readr/Sources/`, not here.

## What `HTMLSource` fixes so a plugin cannot get it wrong

A plugin supplies URLs, selectors, and extraction. It never supplies the
timeout, the concurrency bound, the caching, or the detail merge — those are
applied around it. Two consequences worth knowing before writing one:

- **`id` has no override point.** A plugin passes `name`, `lang`, and `type` to
  `init` and receives what `computeSourceID` produces. "Never hand-pick a source
  ID" is structural here rather than a rule to remember.
- **The detail merge happens in the base type.** `parseDetails(_:known:)` returns
  only what the page said; `HTMLSource` folds it onto the known series through
  `Series.enriched(with:)`. A plugin that "forgot" to preserve a field cannot
  exist, because no plugin performs the merge.

Override `requestHeaders` to satisfy a site that demands a browser-shaped
`User-Agent`. Do not override fetching itself — that would take the timeout and
the concurrency bound with it.
