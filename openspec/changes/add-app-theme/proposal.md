## Why

The Theme picker in the Settings tab looks like it controls the whole app, but
it only changes the Reader. That is what the specs say: the only theme Readr has
is the reader theme, and no spec covers an app-wide appearance. Readers expect a
Settings-tab theme to restyle the whole app, and a theme picked inside the Reader
to affect only the Reader.

## What Changes

- Settings gains an **Appearance** section with an **App Theme** picker
  (System, Light, Dark). It restyles every screen immediately and persists
  across launches. The default is System.
- The existing picker in the Settings **Reader** section is renamed
  **Reader Theme**. It and the Reader's own theme control still change only the
  Reader.
- The reader theme previously titled "System" is now titled **Match App** and
  follows the app theme rather than the device appearance directly. Stored
  values keep their meaning; nobody's reader theme changes.
- Reset Settings also restores the app theme to System.

## Capabilities

### New Capabilities

- `app-appearance`: the app-wide theme — its choices, where it is set, how it
  applies and persists, and how Reset Settings treats it.

### Modified Capabilities

- `unified-reader-screen`: the reader-appearance requirement now says that a
  reader theme change never changes the app theme, and that the Match App reader
  theme follows the app theme.

## Impact

- **Domain:** a new `AppTheme` value and its settings key, beside
  `ReaderPreferences`. `ReaderTheme.system` is retitled; its raw value is kept.
- **UI:** a small observable appearance model built by `ReadrApp`, which
  applies the app color scheme to the whole window. `SettingsState`,
  `SettingsAction`, `SettingsModel`, and `SettingsContent` gain the app theme.
- **Data:** none. The new key is read through `SettingsStore` with a default, so
  no migration is needed.
- **Tests:** domain tests for the new setting; Settings and Reader model tests
  showing that each theme leaves the other untouched and that reset restores
  both.
- **Docs:** codemaps for `UI/Settings`, `UI/Theme`, `UI/Navigation`, and
  `Domain/Model`.

## Non-goals

- A sepia app theme, or custom accent colors.
- Changing the Reader's fixed themes (Light, Sepia, Dark) or their colors.
- Following the reader theme outside the Reader.
