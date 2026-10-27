# Mileage browser preview

A dependency-free, interactive UI demonstration of the native app on `codex/native-mileage`. It follows the app's dark green theme and Start/Stop, history, correction, review, and export flows. The native iPhone app is still the implementation for actual mileage tracking.

From the repository root:

```sh
python3 -m http.server 4173 --bind 127.0.0.1 --directory preview
```

Open http://127.0.0.1:4173. You can also open `preview/index.html` directly in a browser, although browsers may restrict local storage for local files.

- Start a simulated trip, let the miles advance, then stop and save.
- Use **Load sample trips** to try history filtering and a trip flagged for review.
- Open a saved trip to change its category, purpose, notes, or full mileage total. Corrections require a reason and preserve the simulated measurement.
- Reload during a trip to try interrupted-trip recovery.
- Settings offers CSV and JSON preview downloads; every export is labeled as simulated data.
- **Reset preview** clears only this preview's records after confirmation.

The preview does not request location, record actual GPS, use Apple Maps, test background location, or sync with native records. Routes are illustrative. The simulation advances 10 seconds of drive time per visible second, pauses when the page is hidden, and is marked interrupted on reload. Preview JSON has its own format and cannot be imported into the native app. Data stays in this browser's local storage unless exported. No dependencies, API keys, account, or backend are required.
