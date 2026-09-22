# Codemap: `Data/Local/Prefs/`

| File | Responsibility |
| --- | --- |
| `UserDefaultsSettingsStore.swift` | `SettingsStore` backed by `UserDefaults`. The only place `UserDefaults` is named. |
| `InMemorySettingsStore.swift` | `SettingsStore` for previews and tests, so neither leaves settings behind. |

The contract itself is `Readr/Domain/SettingsStore.swift`, so nothing above the
data layer knows where settings live.

Reads go through `object(forKey:)` rather than the typed accessors. `bool(forKey:)`
and friends map "never set" and "set to false" onto the same answer, which would
make any setting whose default is `true` impossible to turn off.

Every key carries its own default, so a setting cannot read back as one value in
one place and another elsewhere. Settings hold the reader's own choices only —
never library state, never chapter content.
