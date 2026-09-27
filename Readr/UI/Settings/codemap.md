# Codemap: `UI/Settings/`

> **Implemented in M7.**

The app theme, reader appearance, registered sources, download storage used and Delete All
Downloads, Rebuild Spotlight Index, app version, and reset.

| File | Responsibility |
| --- | --- |
| `SettingsScreen.swift` | Reads `AppContainer` and `AppAppearanceModel`, owns `SettingsModel`, supplies the bundle version |
| `SettingsContent.swift` | Stateless form: app theme, reader theme/font/size/layout, sources, reset with confirmation, version; owns the preview |
| `SettingsModel.swift` | Reads and writes reader preferences through `SettingsStore` and the app theme through `AppAppearanceModel`; reset clears settings only and reloads the app theme |
| `SettingsState.swift` | Render state and actions |

Reader preferences use the same keys as the Reader's own panel
(`ReaderSettingKeys`), and Settings re-reads them on appear. Reset calls
`SettingsStore.removeAll()`, which is bounded to the settings namespace and never
touches the library.

The app theme and the reader theme are separate settings. App Theme restyles the
whole app through `AppAppearanceModel`; Reader Theme only changes the Reader,
whose default ("Match App") follows the app theme.
