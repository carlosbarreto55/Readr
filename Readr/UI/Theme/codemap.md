# Codemap: `UI/Theme/`

The only place hardcoded colors, spacing values, and typography constants may
appear.

| File | Responsibility |
| --- | --- |
| `Palette.swift` | Semantic colors. System-backed, so light and dark follow without a second palette to maintain. |
| `Spacing.swift` | The spacing scale, plus `screenMargin`. |
| `Typography.swift` | Named `Font` values, every one built from a text style. |
| `ReaderColors.swift` | The Reader's surface and text colors per `ReaderTheme` (system, light, sepia, dark). |

Every entry in `Typography` is a `Font.TextStyle`, never a point size. Readr is a
reading app: a fixed size is a bug, not a style choice.

Reader themes are theme data here, not reader logic. `system` follows `Palette`;
the fixed themes also pin a color scheme so chrome drawn over the page stays
legible. Reader text size is the one computed size in the app: a `@ScaledMetric`
body size multiplied by the reader's scale, so Dynamic Type still drives it.
