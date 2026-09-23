## Context

Every model created one `AsyncStream` of effects in `init` and exposed it as a
stored property. Screens iterate it in a SwiftUI `.task`. Pushing a route makes
the root view disappear, which cancels the task; cancelling a task awaiting an
`AsyncStream` iterator terminates the stream for good. When the view reappears
the task restarts, iterates the finished stream, and exits at once — effects
sent afterwards go nowhere.

## Goals / Non-Goals

**Goals:** navigation works after any number of disappear/appear cycles.

**Non-Goals:** changing routes, effects, or screen structure.

## Decisions

### A fresh stream per subscription

`EffectChannel<Effect>` (Core/Util, main-actor) holds at most one subscriber.
`stream()` finishes the previous subscriber, creates a new stream, and flushes
any effects buffered while nobody was listening; `send(_:)` yields to the
subscriber or buffers. Models expose `var effects` as a computed property calling
`stream()`, so each `.task` run gets a live stream and existing call sites and
tests are unchanged.

*Alternative considered — keep the stream alive by never cancelling the
consumer.* Rejected: the consumer's lifetime is SwiftUI's to decide.

*Alternative considered — drop effects sent with no subscriber.* Rejected: an
effect sent in the gap between a disappearance and the next appearance would be
lost for no reason; buffering costs nothing.

## Risks / Trade-offs

- **A buffered effect navigates late** → effects are only sent from reader
  actions on a visible screen, so the buffer is empty in practice.

## Migration Plan

None. Rollback is `git revert`.

## Open Questions

None.
