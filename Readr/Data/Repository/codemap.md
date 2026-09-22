# Codemap: `Data/Repository/`

Repository implementations. These coordinate `SourceRegistry`, SwiftData,
the filesystem, and Spotlight — and they are the only layer permitted to.

| File | Responsibility |
| --- | --- |
| `SwiftDataLibraryRepository.swift` | `LibraryRepository` over SwiftData: saved series and the chapter state belonging to them. |

A `@ModelActor`, so every access runs on its own `ModelContext` off the main actor.
Entities never leave it — each method maps to domain values before returning.

Saving a series that is already saved refreshes its metadata and leaves the
reader's own state alone: when it was added, when it was last read, and the
progress recorded against its chapters. Removing one takes its chapters with it
through the relationship's cascade delete rule.

Still outstanding: `library-browse-catalog` also requires removal to delete the
series' downloaded payloads. There is no download storage yet; that is wired into
`remove(_:)` when downloads are built.
