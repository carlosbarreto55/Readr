# Source plugin rules

- One directory per site: `Readr/Sources/<SiteName>/<SiteName>.swift`.
- Extend `HTMLSource` for HTML sites. Never add site-specific logic to
  `HTMLSource` itself.
- Implement chapter text **or** chapter pages — never both. A site is a novel
  source or a manhwa source.
- Register the plugin in the `SourceRegistry` built by `Core/DI/`.
- Every plugin ships saved HTML fixtures in `ReadrTests/Fixtures/<sitename>/` and
  a test driving them through a stubbed `URLProtocol`.
- **Never invent CSS selectors.** If the real markup is not in hand, scaffold the
  plugin and stop — a guessed selector produces a source that fails silently.
- Throw on error. Do not log, do not catch, do not return `nil` sentinels.
