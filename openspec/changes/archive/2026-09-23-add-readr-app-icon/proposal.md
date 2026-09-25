## Why

Readr currently has no app icon artwork, so its installed icon does not identify the app or its reading focus. A recognizable icon makes the app easy to find on the iPhone Home Screen.

## What Changes

- Add a finished Readr icon that represents prose and comics in a single open-book mark.
- Package the artwork in the existing iOS app icon asset so installed builds display it.

## Capabilities

### New Capabilities

- `app-icon`: The installed app displays a recognizable Readr icon on the Home Screen.

### Modified Capabilities

None.

## Impact

The existing `AppIcon.appiconset` and resource codemap change. No runtime API, dependency, target structure, or entitlement changes are needed.

## Non-goals

- Redesigning the in-app theme or adding a launch screen illustration.
