import Foundation

public enum RouteRecorder {
    /// Conservative defaults: reject weak fixes, GPS teleports and duplicate time;
    /// never turn a missing section into a straight-line mileage estimate.
    @discardableResult
    public static func append(_ raw: LocationSample, to trip: inout Trip) -> Bool {
        guard trip.isActive, raw.isValid, raw.timestamp >= trip.startedAt else { return false }
        if let observed = trip.lastReliableFix, raw.timestamp <= observed.timestamp { return false }
        var sample = raw
        guard let previous = trip.samples.last else {
            trip.samples.append(sample)
            trip.lastReliableFix = sample
            trip.needsNewSegment = false
            return true
        }
        let seconds = sample.timestamp.timeIntervalSince(previous.timestamp)
        guard seconds > 0 else { return false }
        let observed = trip.lastReliableFix ?? previous
        let observationGap = sample.timestamp.timeIntervalSince(observed.timestamp)
        if trip.needsNewSegment || observationGap > 60 {
            if !trip.needsNewSegment { trip.interrupt(.gpsGap, at: sample.timestamp) }
            trip.samples.append(sample)
            trip.lastReliableFix = sample
            trip.needsNewSegment = false
            return true
        }
        let meters = distance(previous, sample)
        // 70 m/s is roughly 157 mph; no clipping or invented replacement miles.
        guard observationGap > 0, distance(observed, sample) / observationGap <= 70 else { return false }
        let jitterFloor = max(10, min(30, max(previous.accuracy, sample.accuracy) * 0.75))
        // Keep a heartbeat independently of the measured route. A red light
        // must not become a GPS outage just because jitter was filtered out.
        trip.lastReliableFix = sample
        guard meters >= jitterFloor else { return true }
        sample.connectsToPrevious = true
        trip.samples.append(sample)
        trip.gpsDistanceMeters += meters
        return true
    }

    public static func distance(_ a: LocationSample, _ b: LocationSample) -> Double {
        let radians = Double.pi / 180
        let dLat = (b.latitude - a.latitude) * radians
        let dLon = (b.longitude - a.longitude) * radians
        let value = pow(sin(dLat / 2), 2) + cos(a.latitude * radians) *
            cos(b.latitude * radians) * pow(sin(dLon / 2), 2)
        return 6_371_008.8 * 2 * atan2(sqrt(max(0, min(1, value))), sqrt(max(0, 1 - value)))
    }
}
