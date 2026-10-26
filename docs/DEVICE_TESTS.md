# Physical-device acceptance tests

Run on the actual iPhone and record iOS version, app build, starting/ending odometer readings, GPS miles, battery change, and any issue banners. Use a passenger for observations; operate Start/Stop and editing controls only while parked. Do not treat the simulator CI check as evidence for any test below.

| Test | Procedure | Expected result |
|---|---|---|
| Permissions | Fresh install, tap Start, deny location access; then enable it in Settings | No trip begins on denial; settings guidance is shown; Start works after access and Precise Location are enabled |
| Locked screen | Start outside with a clear GPS fix, record odometer, lock screen, drive a known route for 15–20 minutes, park, unlock, Stop | Recording continues while locked; the saved route covers the drive; mileage is compared with the odometer |
| Using Maps | Start a new trip, open Apple Maps or Google Maps, drive, return to Mileage while parked | Mileage records in the background; switching apps does not require Resume |
| No internet | Start a trip; disable Wi-Fi and cellular data while preserving Location Services | Trip saves without a network connection; map tiles may be unavailable, but GPS capture remains functional where GPS works |
| Stationary drift | Start outside, remain parked 10 minutes, then Stop | Mileage remains close to zero; inspect GPS noise and any conservative gap warnings |
| Poor GPS | Include a tunnel or covered parking area where practical | No teleport or straight-line fill across a long gap; trip is flagged when a gap is detected |
| Force quit | On a separate test, swipe Mileage away during an active trip; reopen while parked | Existing trip is preserved, shown as interrupted, and not falsely shown as recording; Resume starts a new route segment |
| Restart phone | Restart during a test trip; unlock and reopen Mileage | The active trip is preserved, requires Resume, and missing mileage is excluded |
| Revoke precision | Change location permission or Precise Location during a test, then reopen | Recording stops; guidance appears; trip is preserved for review/resuming |
| Finish without a fix | Start and stop without receiving sufficient valid GPS points | Zero/partial mileage remains flagged for review; no invented mileage |
| Edits | Correct a completed trip using odometer miles and a reason | The displayed total changes; original GPS miles and route remain; correction appears in CSV |
| Export | Export CSV and JSON to Files; inspect exported records | Quotes/newlines and decimal values are valid; only completed trips are in CSV; original routes and active trip are in backup |
| Long trip | Record 2+ hours, including stops, screen lock, Maps and a phone call | Check route coverage, battery impact, total distance, app memory responsiveness and interrupted-trip warnings |

If a test fails, capture the trip export privately, app/iOS version, timestamps and reproduction steps. Do not upload personal routes to this public repository. Agree an acceptable odometer-vs-GPS error tolerance using several real drives before relying on it for reimbursement or reporting.
