# Codemap: `UI/Theme/`

The only place hardcoded colors, spacing values, and typography constants may
appear.

| File | Responsibility |
| --- | --- |
| `Palette.swift` | Semantic colors. System-backed, so light and dark follow without a second palette to maintain. |
| `Spacing.swift` | The spacing scale, plus `screenMargin`. |
| `Typography.swift` | Named `Font` values, every one built from a text style. |

Every entry in `Typography` is a `Font.TextStyle`, never a point size. Readr is a
reading app: a fixed size is a bug, not a style choice.

Planned: reader themes (light, sepia, dark, black) land here as theme data, not
reader logic, when the Reader is built.
