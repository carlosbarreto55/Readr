# Codemap: `Data/Local/Prefs/`

> **No implementation yet.**

Planned contents:

| File | Responsibility |
| --- | --- |
| `SettingsStore.swift` | Protocol over key-value preference storage |
| `UserDefaultsSettingsStore.swift` | `UserDefaults` implementation |

The protocol exists so `Domain/` and tests never see `UserDefaults`. Preferences
are deliberately not in SwiftData: they need no migration and no relationships.
