# UI rules

- Every screen = four files: `*Screen.swift`, `*Content.swift`, `*Model.swift`,
  `*State.swift`.
- `*Screen` owns the model and handles effects. Never previewed.
- `*Content` is stateless — a pure function of state plus `onAction`. Always has
  a `#Preview`.
- Models are `@Observable @MainActor final class`. Repositories arrive via `init`,
  never via a global or a singleton.
- Navigation goes through `Effect`, never through state.
- Colors, spacing, and typography constants belong in `UI/Theme/`, nowhere else.
- Honor Dynamic Type. No fixed font sizes — this is a reading app.
- Hoist anything used in 2+ screens into `UI/Components/`.
- No `SourceRegistry`, no concrete `Source`, no `ModelContext`, no `URLSession`
  anywhere under `UI/`.
