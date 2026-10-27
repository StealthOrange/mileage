# Mileage design system

`tokens.json` is the shared source of truth for native and browser colors, spacing, corner radii, and base type sizes. The visual direction is quiet, minimal, and functional: neutral off-white or graphite surfaces, restrained forest green actions, readable system type, and clear mileage totals.

Generate the platform constants after editing tokens:

```sh
python3 scripts/generate_design_tokens.py
python3 scripts/generate_project.py
```

The generator writes `App/DesignTokens.swift` and `preview/tokens.css`. Verify them with `python3 scripts/generate_design_tokens.py --check`. Commit generated files with their source so the Xcode project and buildless preview run directly.

`App/Theme.swift` provides adaptive SwiftUI colors, shared typography, button styles, cards, and warning banners. `preview/styles.css` is the browser's global stylesheet, using the same semantic tokens. Native layout uses points and Dynamic Type; browser layout uses CSS pixels and responsive sizing. Base type values are starting points, not fixed text containers.

Appearance defaults to **System**, with explicit **Light** and **Dark** options persisted on each device. Mode choice changes presentation only. Browser preview preferences and trips are separate from native iPhone storage.

Use semantic tokens rather than literal colors in screens. Keep the primary action obvious, targets at least 44 × 44, and body copy readable. Use system accessibility text sizes, visible keyboard focus, sufficient text contrast in both modes, and reduced motion. Recording/review state always includes text or an icon alongside color. Destructive actions require confirmation. Avoid decorative dashboard features that compete with recording or trip records.
