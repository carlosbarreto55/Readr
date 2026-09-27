## 1. Domain

- [x] 1.1 Create `Readr/Domain/Model/AppAppearance.swift` with `AppTheme`, `AppSettingKeys.theme`, and the `SettingsStore` `appTheme` / `setAppTheme` extension; cover default, round trip, and unknown stored value in `ReadrTests/Domain/AppAppearanceTests.swift`
- [x] 1.2 In `Readr/Domain/Model/ReaderPreferences.swift`, retitle `ReaderTheme.system` "Match App" and document that it follows the app theme; update `ReadrTests/Domain/ReaderPreferencesTests.swift` if it asserts titles

## 2. App shell

- [x] 2.1 Create `Readr/UI/Navigation/AppAppearanceModel.swift` (observable theme, `set`, `reload`, `colorScheme`, environment key); covered through `ReadrTests/UI/SettingsModelTests.swift`
- [x] 2.2 In `Readr/ReadrApp.swift`, build the model with the container, apply its color scheme to the window content, and put it in the environment

## 3. Settings

- [x] 3.1 In `Readr/UI/Settings/SettingsState.swift`, `SettingsModel.swift`, and `SettingsScreen.swift`, add the app theme (`setAppTheme`, rename `setTheme` to `setReaderTheme`, reload on appear and reset); cover independence and reset in `ReadrTests/UI/SettingsModelTests.swift`
- [x] 3.2 In `Readr/UI/Settings/SettingsContent.swift`, add the Appearance section with App Theme, relabel Reader Theme, and update the preview
- [x] 3.3 Show that a reader theme change leaves the app theme unchanged: the Reader writes only through `setReaderPreferences`, covered in `ReadrTests/Domain/AppAppearanceTests.swift`

## 4. Docs and verify

- [x] 4.1 Update `Readr/Domain/Model/codemap.md`, `Readr/UI/Theme/codemap.md`, `Readr/UI/Navigation/codemap.md`, and `Readr/UI/Settings/codemap.md`
- [x] 4.2 Run `/verify` and `openspec validate add-app-theme`
- [ ] 4.3 On the simulator, check App Theme Dark/Light/System (including System after Dark), a Sepia reader over a Dark app, relaunch, and Reset Settings
