# Mileage instrument preview

A dependency-free browser demonstration of the native Mileage app, implemented against the supplied Obsidian / Instrument dashboard, active-drive, history, detail, reports, and settings references. It supports System, Light, and Dark appearance and preserves existing preview records.

From the repository root:

```sh
python3 -m http.server 4173 --bind 127.0.0.1 --directory preview
```

Open http://127.0.0.1:4173. Keep `index.html`, `styles.css`, `tokens.css`, `map.js`, and `app.js` together when copying this preview.

## Try the app

- **Home:** a 270-degree instrument shows this week's completed mileage and actual daily totals. Start drive begins a simulated drive. Recent trips show saved routes, categories, times, and mileage.
- **Active drive:** watch the distance and elapsed simulation time advance, pause/resume, change category, and end/save the drive. Reloading interrupts it and requires Resume.
- **Trips:** filter by category, choose a month, search routes/purposes/notes, or add a verified manual trip. Manual entry requires a mileage source and has no GPS route.
- **Trip details:** edit category, purpose, vehicle, and notes, then Save changes. Mileage corrections require a valid full-trip total and source, retain the original measurement, and remain distinct from GPS mileage.
- **Reports:** view computed monthly totals, business/personal totals, weekly bars, and trip counts. CSV downloads the selected month. PDF opens the system print dialog with a dedicated report layout; choose Save as PDF. The preview does not claim a PDF file was downloaded.
- **Settings:** choose appearance, set a local profile name, vehicle name, or default category, and download CSV/JSON preview records. No online account is created. Reset preview data removes only preview trips after confirmation and keeps appearance/profile preferences.

**Load sample trips** adds the five Houston routes shown in the references: Downtown → Energy Corridor (18.7 mi), Heights → Hobby Airport (22.3 mi), The Woodlands → Downtown (26.1 mi), Sugar Land → Medical Center (19.6 mi), and Katy → Galleria (41.7 mi), totaling 128.4 mi. They are added once per preview storage and preserve pre-existing records. No samples are inserted automatically. Dashboard and reports always calculate from saved records rather than displaying reference-only totals.

## Shared design system

`styles.css` is the global stylesheet for the instrument, bottom navigation, maps, route lists, controls, forms, reports, dialogs, and accessibility states. `tokens.css` is generated from the repository's `design/tokens.json` by `scripts/generate_design_tokens.py`, alongside native Swift tokens. Change the source tokens to keep the native app and browser palette, type scale, spacing, and radii aligned. Light mode uses dark accent text where lime would have insufficient contrast.

`map.js` draws an original, local Houston illustration with dense neighborhood streets, freeway shields, parks, bayou shapes, labels, and a partial-route simulation. It has no remote tiles, API calls, keys, or screenshot crops. Its map and routes are illustrative, not recorded GPS.

## Data and validation boundaries

Trip data remains under the existing `mileage-browser-preview-v1` local-storage key and version-1 schema. Additional route, manual-entry, pause, and vehicle fields are optional. Appearance and local profile preferences use separate keys. Changing theme never changes trip records.

The simulation advances ten seconds per visible second at about 0.08 miles per second. It pauses when the page is hidden and after an explicit Pause. All exports identify records as simulated or manually entered browser-preview data. Preview JSON is separate from native iPhone backups and cannot be imported into the native app.

No real location permission, GPS, automatic drive detection, motion detection, cloud sync, or native background tracking is claimed or enabled by this browser preview. Those capabilities and physical-device acceptance tests belong to the native iPhone app.
