# Codemap: `Domain/`

> **Models and the first two contracts implemented.** Each remaining contract
> arrives with the change that implements it — a protocol with no caller is a
> guess about a milestone that has not been designed.

The framework-free core. Nothing here imports SwiftUI, SwiftData, `URLSession`,
or SwiftSoup — that is invariant 1, and it is what lets domain tests run without
a simulator.

| File | Responsibility |
| --- | --- |
| `LibraryRepository.swift` | Saved series and their chapter state. Domain values in and out. |
| `SettingsStore.swift` | The reader's settings, plus `SettingKey` and `RawSettingKey`. |
| `Model/` | Immutable `Sendable` models — see its own codemap. |

Planned, each arriving with the change that implements it: a chapter repository
for refresh merging, a catalog repository over sources, a download repository, and
a search repository.

`SettingKey` is named that way rather than `PreferenceKey` because SwiftUI already
defines a `PreferenceKey` protocol, and a screen should never have to
disambiguate.
