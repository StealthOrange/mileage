import CoreLocation
import UIKit
import Combine

@MainActor
final class LocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined
    @Published private(set) var hasPreciseLocation = false
    @Published private(set) var lastFixAt: Date?
    @Published var message: String?

    private enum Intent { case new(TripCategory, String), resume }
    private var pendingIntent: Intent?
    private let manager = CLLocationManager()
    private let store: MileageStore

    init(store: MileageStore) {
        self.store = store
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        refreshStatus()
    }

    func start(category: TripCategory, purpose: String) { begin(.new(category, purpose)) }
    func resume() { begin(.resume) }

    func stop() {
        stopHardware()
        if !store.finish(lastFixAt: lastFixAt) { message = store.storageError }
    }

    func refreshStatus() {
        authorization = manager.authorizationStatus
        hasPreciseLocation = manager.accuracyAuthorization == .fullAccuracy
        if isRecording && (!canRecord || !hasPreciseLocation) {
            pauseForPermissionChange()
        }
    }

    private var canRecord: Bool {
        authorization == .authorizedAlways || authorization == .authorizedWhenInUse
    }

    private func begin(_ intent: Intent) {
        guard !store.isReadOnly, !isRecording else { return }
        guard UIApplication.shared.applicationState == .active else {
            message = "Open Mileage to start or resume a trip."
            return
        }
        refreshStatus()
        switch authorization {
        case .notDetermined:
            pendingIntent = intent
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            message = "Enable location access and Precise Location for Mileage in iPhone Settings."
        case .authorizedAlways, .authorizedWhenInUse:
            guard hasPreciseLocation else {
                message = "Turn on Precise Location for Mileage in iPhone Settings before recording."
                return
            }
            let saved: Bool
            switch intent {
            case let .new(category, purpose): saved = store.start(category: category, purpose: purpose)
            case .resume:
                saved = store.activeTrip != nil && store.interrupt(.gpsGap)
            }
            guard saved else { message = store.storageError; return }
            message = nil
            lastFixAt = nil
            // Start in the foreground. This keeps an explicitly started trip
            // running under When In Use authorization with iOS's blue indicator.
            manager.allowsBackgroundLocationUpdates = true
            isRecording = true
            manager.startUpdatingLocation()
        @unknown default:
            message = "Location access is unavailable on this device."
        }
    }

    private func stopHardware() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        isRecording = false
        pendingIntent = nil
    }

    private func pauseForPermissionChange() {
        stopHardware()
        _ = store.interrupt(.permissionChanged)
        message = "Recording stopped because location access changed. Enable Precise Location, then resume your trip."
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        refreshStatus()
        if let intent = pendingIntent, canRecord {
            pendingIntent = nil
            begin(intent)
        } else if authorization == .denied || authorization == .restricted {
            pendingIntent = nil
            message = "Location access is off. Enable it in iPhone Settings to record trips."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isRecording else { return }
        let now = Date()
        let samples = locations.filter { $0.timestamp <= now.addingTimeInterval(5) }.map {
            LocationSample(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude,
                           accuracy: $0.horizontalAccuracy, timestamp: $0.timestamp)
        }
        if let fresh = samples.filter({ $0.isValid && $0.timestamp >= (store.activeTrip?.startedAt ?? now) })
            .max(by: { $0.timestamp < $1.timestamp }) {
            lastFixAt = max(lastFixAt ?? fresh.timestamp, fresh.timestamp)
            message = nil
        }
        if !store.append(samples) {
            stopHardware()
            _ = store.interrupt(.storageFailure)
            message = store.storageError ?? "Recording stopped. Resume when storage is available."
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard isRecording else { return }
        if (error as? CLError)?.code == .denied { pauseForPermissionChange() }
        else { message = "GPS is temporarily unavailable. Recording will continue when the signal returns. Review the trip for gaps." }
    }
}
