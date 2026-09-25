## Context

`AppIcon.appiconset` contains only an empty universal iOS slot. The existing target already names `AppIcon` as its app icon asset. The generated artwork is square and represents text and comic pages in an open book.

## Goals / Non-Goals

**Goals:** Ship a crisp icon in the current iPhone app target and verify it appears in a device build.

**Non-Goals:** Change the app theme, bundle identifier, target structure, or signing configuration.

## Decisions

- Use a single opaque 1024 × 1024 PNG in the existing universal iOS icon slot. This matches the catalog's current shape and lets Xcode generate device sizes. Adding separate size variants would duplicate artwork without a benefit for this target.
- Keep the artwork full bleed and square. iOS applies its own icon mask; baking rounded corners into the PNG would cause an unwanted inset.
- Use a dark field and a high-contrast book silhouette, with prose lines on one page and comic panels on the other. This keeps the reading concept recognizable at Home Screen size.

## Risks / Trade-offs

- Fine page details may disappear at small sizes → Check a downscaled preview and rely on the broad book silhouette.
- A stale installed icon may be cached by iOS → Verify the built asset catalog and reinstall on the connected device.

## Migration Plan

Replace the empty icon slot with the PNG and rebuild. Rolling back means restoring the prior asset catalog contents.

## Open Questions

None.
