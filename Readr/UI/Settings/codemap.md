# Codemap: `UI/Settings/`

> **Implemented in M7.**

Reader appearance, registered sources, download storage used and Delete All
Downloads, app version, and reset.

| File | Responsibility |
| --- | --- |
| `SettingsScreen.swift` | Reads `AppContainer`, owns `SettingsModel`, supplies the bundle version |
| `SettingsContent.swift` | Stateless form: reader theme/font/size/layout, sources, reset with confirmation, version; owns the preview |
| `SettingsModel.swift` | Reads and writes reader preferences through `SettingsStore`; reset clears settings only |
| `SettingsState.swift` | Render state and actions |

Reader preferences use the same keys as the Reader's own panel
(`ReaderSettingKeys`), and Settings re-reads them on appear. Reset calls
`SettingsStore.removeAll()`, which is bounded to the settings namespace and never
touches the library.
