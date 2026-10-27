# Mileage

A personal iPhone mileage tracker with **Start/Stop recording that can continue with the screen locked or while using Maps**. Built with SwiftUI, Core Location, and MapKit. iOS 17 or later. No third-party packages, server, account, or subscription in the app.

## Included

- Start and stop trips; Business and Personal categories, purpose and notes.
- Background GPS configured using Apple's supported location background mode.
- Local, atomic trip checkpoints, including while the device is locked after its first unlock.
- Route maps, monthly business miles, searchable trip history, CSV exports and full JSON backups.
- GPS quality and speed filters; missing sections are excluded from mileage and map lines.
- Interrupted-trip recovery with an explicit Resume button and review warnings.
- Verified mileage corrections that preserve the original GPS measurement and require a reason.
- A macOS CI workflow for core tests, an unsigned iPhone Simulator build, and launch smoke test.

**This is a native iPhone app, not a PWA.** An iPhone website cannot reliably record location while hidden or locked. Next.js and Convex are not needed for this single-user, offline-first version; a web dashboard or secure cloud sync can be added later.

## Run

For an interactive browser demonstration without Xcode, see [the browser preview](preview/README.md). It uses simulated trips; actual background GPS still requires the native iPhone app.

Open `Mileage.xcodeproj` in a current Xcode, select the `Mileage` scheme and an iPhone Simulator, then Run. For your actual phone, configure your Apple signing team and bundle identifier. See [installation and TestFlight instructions](docs/INSTALL.md).

```sh
swift test
python3 scripts/generate_project.py --check
xcodebuild build -project Mileage.xcodeproj -scheme Mileage \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO
```

The checked-in Xcode project opens directly without a generation tool. If adding/removing Swift source files, run `python3 scripts/generate_project.py` and commit the result. The generator uses Python's standard library. Signing choices made inside Xcode are local project changes; reapply them after regenerating.

## Before relying on a mileage total

Start the trip while parked with Mileage in the foreground. Allow location access and keep **Precise Location** enabled. When In Use permission is sufficient for an explicitly started trip with the configured background mode and iOS location indicator. Recording stops when you tap Stop. Always authorization and continuous monitoring outside a started trip are not requested.

Do not swipe Mileage away during a trip. Force-quitting, rebooting, permission changes, GPS loss or storage failures can interrupt recording. Reopen the app and tap Resume when needed. The app flags interrupted trips and does not fill missing routes with straight-line guesses. GPS distances are approximate and should be compared with an odometer during the [physical-device acceptance test](docs/DEVICE_TESTS.md).

**Automatic drive detection is not included.** It needs additional native lifecycle/detection work and real-device battery and false-positive testing. This first release uses manual Start/Stop with native background GPS.

## Storage and privacy

Trip data is stored in the app's Application Support directory. No route samples are sent to a Mileage server. Apple Maps and your device backup settings still apply. Export backups regularly: deleting the app deletes its local records. CSV includes completed trips and start/end coordinates; JSON includes full routes and any active trip. Backup import/restore is not implemented yet. See [privacy](docs/PRIVACY.md).

No API keys, signing identities, personal routes, or Apple account credentials belong in this public repository.

## Validation boundary

CI verifies domain logic and simulator compilation/launch. Simulator results **do not prove locked-screen GPS behavior on a real iPhone**. Signed installation, TestFlight upload, and the device checklist are separate remaining steps. A simulator build cannot be installed on an iPhone.

## Apple references

- [Background location configuration](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates)
- [Location authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)
- [File protection for locked-screen persistence](https://developer.apple.com/documentation/foundation/fileprotectiontype/completeuntilfirstuserauthentication)
- [TestFlight](https://developer.apple.com/testflight/)
