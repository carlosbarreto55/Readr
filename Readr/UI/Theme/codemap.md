# Codemap: `UI/Theme/`

> **No implementation yet.**

The only place hardcoded colors, spacing values, and typography constants may
appear.

Planned contents:

| File | Responsibility |
| --- | --- |
| `Palette.swift` | Semantic colors, light and dark |
| `Spacing.swift` | The spacing scale |
| `Typography.swift` | Dynamic Type text styles, including reader themes |

Reader themes (light, sepia, dark, black) are theme data, not reader logic.
Typography must scale with Dynamic Type — fixed point sizes are a bug here.
