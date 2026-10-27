# Mileage browser preview

A dependency-free, interactive UI demonstration of the native app on `codex/native-mileage`. It follows the app's shared design system and Start/Stop, history, correction, review, and export flows, with System, Light, and Dark appearance modes. The native iPhone app is still the implementation for actual mileage tracking.

From the repository root:

```sh
python3 -m http.server 4173 --bind 127.0.0.1 --directory preview
```

Open http://127.0.0.1:4173. You can also open `preview/index.html` directly in a browser, although browsers may restrict local storage for local files.

- Use **Appearance** in the toolbar or **Color theme** in Settings to choose System, Light, or Dark. The preference persists in this browser and System follows the device setting.
- Start a simulated trip, let the miles advance, then stop and save.
- Use **Load sample trips** to try history filtering and a trip flagged for review.
- Open a saved trip to change its category, purpose, notes, or full mileage total. Corrections require a reason and preserve the simulated measurement.
- Reload during a trip to try interrupted-trip recovery.
- Settings offers CSV and JSON preview downloads; every export is labeled as simulated data.
- **Reset preview** clears only this preview's records after confirmation.

The preview does not request location, record actual GPS, use Apple Maps, test background location, or sync with native records. Routes are illustrative. The simulation advances 10 seconds of drive time per visible second, pauses when the page is hidden, and is marked interrupted on reload. Preview JSON has its own format and cannot be imported into the native app. Data stays in this browser's local storage unless exported. No dependencies, API keys, account, or backend are required.

## Shared styles

`styles.css` is the global stylesheet for page layout, type hierarchy, controls, forms, cards, history rows, dialogs, and accessibility states. `app.js` renders the app and owns browser interaction logic. `tokens.css` is generated from `design/tokens.json` by `scripts/generate_design_tokens.py`, alongside the native Swift design tokens. Edit the source tokens to keep colors, spacing, typography, and radii consistent across the native app and preview.

The preview uses system typography, semantic light/dark colors, visible keyboard focus, at least 44px control targets, 12px or larger meaningful labels, reduced-motion support, and accessible modal dialogs with Escape/backdrop dismissal and focus restoration. Keep all four browser files (`index.html`, `styles.css`, `tokens.css`, `app.js`) together when copying the preview.
