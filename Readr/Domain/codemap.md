# Codemap: `Domain/`

> **Models and the first three contracts implemented.** Each remaining contract
> arrives with the change that implements it — a protocol with no caller is a
> guess about a milestone that has not been designed.

The framework-free core. Nothing here imports SwiftUI, SwiftData, `URLSession`,
or SwiftSoup — that is invariant 1, and it is what lets domain tests run without
a simulator.

| File | Responsibility |
| --- | --- |
| `LibraryRepository.swift` | Saved series, reader-owned library timestamps, and chapter state. Domain values in and out. |
| `SettingsStore.swift` | The reader's settings, plus `SettingKey` and `RawSettingKey`. |
| `CatalogRepository.swift` | Remote catalog data over sources. Every method takes `refresh`, so a caller states at the call site whether it wants the cache. |
| `Model/` | Immutable `Sendable` models — see its own codemap. |

Planned, each arriving with the change that implements it: a chapter repository
for refresh merging, a download repository, and a search repository.

`SettingKey` is named that way rather than `PreferenceKey` because SwiftUI already
defines a `PreferenceKey` protocol, and a screen should never have to
disambiguate. Its name must begin with `SettingNamespace.prefix`, enforced by a
precondition: without a namespace, "clear every setting" has no bound narrower
than the whole `UserDefaults` domain, which the app shares with the system
frameworks.

`Model/Series+Enriched.swift` holds the detail merge. It lives here rather than
beside `HTMLSource` because it is a pure operation on a domain value, and testing
it needs no network, no parser, and no plugin. Identity is not a parameter of the
merge — `sourceID` and `url` come from the receiver and the incoming value is
never consulted for them — so a detail page that resolved elsewhere cannot
quietly turn a series into a different one.
