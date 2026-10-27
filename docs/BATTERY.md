# Battery and background recording

Mileage uses a deliberately limited policy for this personal beta: location hardware runs only during a drive the user starts. Automatic drive detection is not implemented. The app does not keep GPS, motion detection, beacon monitoring, timers, or network polling running while waiting for a trip.

| State | Location policy |
| --- | --- |
| No active drive | Standard location updates and background delivery are off. |
| Recording | Standard accurate updates, automotive activity type, and native background location delivery are on. The iOS location indicator remains visible. |
| Paused by the user | Location updates and background delivery stop. The trip stays open; resuming starts a separate route segment. |
| Ended, permission interrupted, or storage failure | Location hardware stops. A completed or interrupted record is saved where storage permits. |

The app asks for **When In Use** and **Precise Location** when starting a drive. An explicitly started standard-location session can continue while the phone is locked or another app is visible when background location and its indicator are configured. Reopening is required after termination; force-quitting or restarting is not a supported way to keep recording. See Apple's [When In Use authorization guidance](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services) and [background delivery property](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates).

## Energy choices in the current implementation

The biggest control is duration: call `stopUpdatingLocation()` immediately when recording is no longer needed. Apple recommends reducing accuracy and update frequency to the needs of the feature and avoiding unnecessary background location work. Mileage requires road-level route measurement during an active drive; it uses standard `kCLLocationAccuracyBest`, not `BestForNavigation`, which requests extra sensor work. It does not request heading updates or keep the screen awake. [Apple's energy guidance](https://developer.apple.com/documentation/xcode/accessing-the-device-s-location-efficiently), [navigation accuracy power requirements](https://developer.apple.com/documentation/corelocation/kcllocationaccuracybestfornavigation).

Two settings intentionally favor continuity during an active drive:

- `distanceFilter` stays unset (`kCLDistanceFilterNone`). The recorder uses reliable stationary observations to distinguish waiting at traffic lights from lost GPS. Simply suppressing all updates until the phone moves would make long stops look like missing route sections. The recorder rejects jitter from measured distance while retaining a fresh observation heartbeat.
- `pausesLocationUpdatesAutomatically` stays false. Apple's property documentation says an automatic pause under When In Use authorization ends access until the app launches again and restarts updates. An unnoticed automatic pause would violate the locked-screen drive requirement. The visible **Pause** action provides a real battery-saving stop that the user controls. [Apple's automatic-pause lifecycle documentation](https://developer.apple.com/documentation/corelocation/cllocationmanager/pauseslocationupdatesautomatically).

These settings are a bounded tradeoff for reliable manually started recording. They are not a claim of minimum possible power consumption. A migration to Apple's newer stationary-aware location streams should be evaluated with route-gap tests and device measurements rather than combined with this UI change. Storage checkpoints remain durable; this pass does not batch away recent route samples to claim unmeasured energy savings.

## How other mileage apps handle detection

MileIQ documents using motion and location detection instead of continuous GPS, and sleeping while stationary. Its drive detection also considers movement, speed, cell/Wi-Fi location information, and a rest interval before closing a drive. These are the vendor's documented behaviors, not a claim about its private implementation or a battery guarantee for Mileage. [MileIQ battery behavior](https://support.mileiq.com/hc/en-us/articles/204480735-Battery-life-best-practices), [MileIQ drive detection](https://support.mileiq.com/hc/en-us/articles/204475585-What-determines-a-drive).

Everlance documents using GPS together with Motion & Fitness sensors and nearby Wi-Fi information. [Everlance tracking guidance](https://help.everlance.com/hc/en-us/articles/45326316734491-Why-is-My-Trip-Not-Recorded).

Driversnote documents motion-based detection and an optional Bluetooth Low Energy iBeacon placed in the car. The beacon signals when to start and stop tracking, limiting recording to that vehicle. [Driversnote iBeacon behavior](https://www.driversnote.com/ibeacon).

The common architecture is low-power detection while idle, accurate route recording during a drive, then returning to idle. Adding automatic detection to Mileage would require a separate native lifecycle and permission design plus real tests for missed short trips, passenger/public-transit false positives, rest stops, app termination, and battery use. The current UI must show automatic tracking as unavailable rather than implying it is active.

## Measure on the user's iPhone

Battery use depends on GPS reception, phone model and battery health, temperature, screen activity, Maps use, and drive duration. Simulator success cannot establish power use or locked-screen reliability.

1. Compare an idle period with no active drive to an idle baseline. Check that Mileage has no active location indicator.
2. Repeat a representative 30–60 minute route with Mileage recording and the screen locked; include traffic lights and a longer stop. Compare the route/miles with an odometer.
3. Repeat using Maps while Mileage records in the background. Note overall battery change and Mileage's activity in **Settings → Battery**; an app's share of battery activity is not the same as percentage points of charge lost.
4. Pause while parked, wait, then resume. Confirm location stops during the pause and the map does not bridge it. End the trip and verify location stops again.
5. Use Xcode's energy/performance tools to inspect CPU, location, disk, and wakeups before making further optimizations. Retest on the same route after any policy change.

No fixed “percent per hour” claim is made before these device measurements.
