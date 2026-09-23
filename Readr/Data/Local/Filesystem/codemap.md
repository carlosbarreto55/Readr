# Codemap: `Data/Local/Filesystem/`

> **Implemented in M8.**

| File | Responsibility |
| --- | --- |
| `ChapterPayloadStore.swift` | Stages, commits, reads, deletes, and sizes chapter payloads under the `Downloads` directory, which it creates and excludes from backup. |

Layout:

```
Application Support/Readr/Downloads/<sourceID>/<seriesKey>/<chapterKey>/
    manifest.json
    chapter.html            (novel)
    page-0001.jpg …         (manhwa)
```

Path components come from `EntityKey.path(for:)`, whose derivation is pinned by
hardcoded tests: changing it strands every stored chapter.

A chapter is written into a sibling `<chapterKey>.partial` directory and renamed
into place after its manifest, so a chapter directory is complete or absent. A
read requires the manifest and every file it names; otherwise the chapter is not
stored. Application Support rather than Caches, because the system evicts Caches
under disk pressure and offline reading is the whole point. See
`architecture.md` §6.3.

Synchronous file I/O: called only from the download repository's actor and the
detached download task, never from the main actor.
