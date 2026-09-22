# Codemap: `Sources/`

> **No source plugins yet.**

One directory per supported site. Read `AGENTS.md` in this directory before
adding one.

```
Sources/<SiteName>/<SiteName>.swift
```

Each plugin extends `HTMLSource`, implements chapter text **or** chapter pages,
registers itself in `Core/DI/SourceRegistration.swift`, and ships fixtures in
`ReadrTests/Fixtures/<sitename>/`.

Naming note: this directory is `Sources/` to match the `Source` / `SourceRegistry`
/ `source-author` vocabulary used throughout the repository. There is no root
`Package.swift`, so it does not collide with SwiftPM's reserved layout.
