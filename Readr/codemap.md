# Codemap: `Readr/`

> **All nine milestones.** Every directory holds code.

Application source root. Every subdirectory maps to a layer in
`architecture.md` §3.

| Directory | Layer | Responsibility |
| --- | --- | --- |
| `Core/` | Infrastructure | Composition root and cross-cutting utilities |
| `Domain/` | Domain | Immutable models and repository protocols |
| `Data/` | Data + Infrastructure | Repository implementations, persistence, `Source` contract |
| `Sources/` | Source plugins | One directory per supported site |
| `UI/` | UI + Presentation | Screens, navigation, theme, shared views |
| `Background/` | Infrastructure | `BGTaskScheduler` entry points |
| `Resources/` | — | Asset catalog and generated `Info.plist` |

`ReadrApp.swift` builds `AppContainer` and injects it into the SwiftUI
environment. It is the only file permitted to construct the object graph.
