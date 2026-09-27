## Context

The only theme Readr has is `ReaderPreferences.theme`, stored under
`readr.reader.theme`. The Settings tab shows it as "Theme" in its Reader
section, and only `ReaderContent` applies it, through
`.preferredColorScheme(ReaderColors.colorScheme(theme))` and the `ReaderColors`
surfaces. The Reader is shown as a `fullScreenCover` over `RootTabView`, so its
color-scheme preference applies to that presentation only. Nothing sets a color
scheme for the tab shell, which therefore always follows the device.

`SettingsStore` is a synchronous, non-observable contract. `SettingsModel` reads
it on `.appeared` because the Reader can change reader preferences behind its
back.

## Goals / Non-Goals

**Goals:**

- An app theme that restyles the whole shell the moment it is picked.
- The reader theme stays a Reader-only choice, and its default follows the app.
- No migration and no change to anyone's stored reader theme.

**Non-Goals:**

- A sepia app theme; sepia is a reading surface, not a UI palette.
- Making `SettingsStore` observable.

## Decisions

**A separate `AppTheme` rather than reusing `ReaderTheme`.** Sepia has no
meaning for the whole app, and sharing one enum would couple the two choices the
specs now keep independent. `AppTheme` lives in
`Domain/Model/AppAppearance.swift` with its `RawSettingKey`
(`readr.app.theme`, default `.system`) and a `SettingsStore` extension, following
`ReaderPreferences.swift`.

**`ReaderTheme.system` becomes "Match App", with the same raw value.**
`ReaderColors.colorScheme(.system)` is already `nil` and its colors are the
semantic `Palette`, so inside a shell forced to Dark it already renders dark.
Only the title and doc comment change. Keeping `"system"` means stored values
read back unchanged.

**An observable `AppAppearanceModel` owned by `ReadrApp`.** The shell needs to
re-render when the theme changes, and the store cannot tell it. A small
`@Observable @MainActor` model (`UI/Navigation/AppAppearanceModel.swift`) built
from `container.settings` holds the current theme, writes through the store, and
exposes `colorScheme`. `ReadrApp` builds it in `init` next to the container, so
the very first frame already has the stored theme, applies
`.preferredColorScheme` to the window content, and puts it in the environment.
`RootTabView` cannot build it early enough: it only gets the container from the
environment, after its first render. `SettingsScreen` passes it to `SettingsModel.init`, keeping
dependencies on `init` as `UI/AGENTS.md` requires. Alternatives: `@AppStorage`
would name `UserDefaults` in UI, which `preferences-store` forbids; making
`SettingsStore` observable would widen a domain contract for one caller.

**Reset goes through the appearance model.** `SettingsModel.confirmReset` clears
the store and then calls `appearance.reload()`, so the shell returns to System at
once rather than on the next launch.

## Risks / Trade-offs

- [SwiftUI may not restore the device appearance when `.preferredColorScheme`
  goes from an explicit value back to `nil`] → Check System → Dark → System on
  the simulator. If it sticks, set `overrideUserInterfaceStyle` on the scene's
  windows instead, mapping `AppTheme` to
  `UIUserInterfaceStyle`.
- [The Reader's fixed themes pin a scheme on its presentation] → That is the
  intended Reader-only behavior; the shell underneath keeps the app theme.

## Migration Plan

None. The new key defaults to System, which matches today's shell behavior.
