# Mileage design system

`tokens.json` is the shared source of truth for native and browser colors, spacing, corner radii, and base type sizes. The visual direction follows the supplied Obsidian / Instrument references: blue-black or silver-white surfaces, lime action pills and route strokes, finely ticked mileage gauges, map layers with faded edges, compact divider rows, and persistent Home / Trips / Reports / Settings navigation.

Generate the platform constants after editing tokens:

```sh
python3 scripts/generate_design_tokens.py
python3 scripts/generate_project.py
```

The generator writes `App/DesignTokens.swift` and `preview/tokens.css`. Verify them with `python3 scripts/generate_design_tokens.py --check`. Commit generated files with their source so the Xcode project and buildless preview run directly.

`App/Theme.swift` provides adaptive SwiftUI colors, shared typography, button styles, cards, and warning banners. `preview/styles.css` is the browser's global stylesheet, using the same semantic tokens. Native layout uses points and Dynamic Type; browser layout uses CSS pixels and responsive sizing. Base type values are starting points, not fixed text containers.

Appearance defaults to **System**, with explicit **Light** and **Dark** options persisted on each device. Mode choice changes presentation only. Browser preview preferences and trips are separate from native iPhone storage.

Use semantic tokens rather than literal colors in screens. Keep the primary action obvious, targets at least 44 × 44, and body copy readable. Use system accessibility text sizes, visible keyboard focus, sufficient text contrast in both modes, and reduced motion. Recording/review state always includes text or an icon alongside color. Destructive actions require confirmation. Avoid decorative dashboard features that compete with recording or trip records.

## Reference screen rules

Home uses a 270-degree instrument dial with actual weekly mileage and daily bars, a recorded-route map, Start drive, and recent trips. Active drive uses the same dial with elapsed time, live route, category, Pause/Resume, and End drive. Reports uses a 180-degree instrument and selected-month totals, weekly category bars, and real CSV/PDF exports. Trip history groups records by date; details preserve the original GPS measurement when a verified total is entered.

Lime is used for actions, gauge arcs, and routes. Light-theme text uses the separate `accentText` token to remain readable on white. The dial is accompanied by accessible mileage text and status labels. Every screen adapts to System, Light, or Dark appearance. The native map uses MapKit and recorded coordinates; the browser map is explicitly an illustrative simulation. Screens do not claim automatic detection or cloud backups are active.
