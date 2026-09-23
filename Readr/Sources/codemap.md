# Codemap: `Sources/`

> **Two source plugins ship:** FreeWebNovel for English novel text and
> AsuraScans for English manhwa pages.

One directory per supported site. Read `AGENTS.md` in this directory before
adding one.

```
Sources/<SiteName>/<SiteName>.swift
```

Each plugin extends `HTMLSource`, implements chapter text **or** chapter pages,
registers itself in `Core/DI/SourceRegistration.swift`, and ships fixtures in
`ReadrTests/Fixtures/<sitename>/`.

| Directory | Content | Catalogs |
| --- | --- | --- |
| `FreeWebNovel/` | `.novel` / `.text(html:)` | Most popular, latest releases, search |
| `AsuraScans/` | `.manhwa` / `.pages(imageURLs:)` | Browse, homepage latest updates, search |

Both are ports of ReaderParser's observed selectors. They use the
server-rendered HTML paths supported by `HTMLSource`; their tests serve saved
markup through `StubURLProtocol` and never contact the live sites.

Naming note: this directory is `Sources/` to match the `Source` / `SourceRegistry`
/ `source-author` vocabulary used throughout the repository. There is no root
`Package.swift`, so it does not collide with SwiftPM's reserved layout.
