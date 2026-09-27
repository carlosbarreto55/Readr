# Codemap: `Sources/`

> **Four source plugins ship:** FreeWebNovel for English novel text,
> AsuraScans for English manhwa pages, MangaPill for English manga pages, and
> ReadComicsOnline for English western comics (Marvel, DC, Image).

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
| `MangaPill/` | `.manga` / `.pages(imageURLs:)` | Manga-only catalog, finite catalog feed, search |
| `ReadComicsOnline/` | `.comic` / `.pages(imageURLs:)` | Full single-page catalog, weekly new releases, search |

All four use server-rendered HTML paths supported by `HTMLSource`; their tests
serve saved markup through `StubURLProtocol` and never contact the live sites.
ReadComicsOnline is the one exception inside a page: its issue markup renders only
page 1, so `parsePages` decodes the ordered page list from the embedded Next.js
flight payload instead of selecting `<img>` elements.

Naming note: this directory is `Sources/` to match the `Source` / `SourceRegistry`
/ `source-author` vocabulary used throughout the repository. There is no root
`Package.swift`, so it does not collide with SwiftPM's reserved layout.
