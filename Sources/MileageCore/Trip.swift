import Foundation

public enum TripCategory: String, Codable, CaseIterable, Identifiable {
    case business = "Business"
    case personal = "Personal"
    public var id: String { rawValue }
}

public enum RecordingIssue: String, Codable {
    case gpsGap = "GPS signal gap"
    case appRestarted = "App restarted during trip"
    case permissionChanged = "Location permission or precision changed"
    case storageFailure = "Recording stopped after a storage error"
    case insufficientGPS = "Not enough GPS points to measure the trip"
}

public struct TripIssue: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var date: Date
    public var reason: RecordingIssue
}

public struct LocationSample: Codable, Equatable {
    public var latitude: Double
    public var longitude: Double
    public var accuracy: Double
    public var timestamp: Date
    public var connectsToPrevious = false

    public init(latitude: Double, longitude: Double, accuracy: Double, timestamp: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.timestamp = timestamp
    }

    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite && accuracy.isFinite &&
        (-90...90).contains(latitude) && (-180...180).contains(longitude) &&
        (0...50).contains(accuracy)
    }
}

public struct Trip: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var startedAt: Date
    public var endedAt: Date?
    public var category: TripCategory
    public var purpose: String
    public var notes = ""
    public var samples: [LocationSample] = []
    public var gpsDistanceMeters: Double = 0
    public var adjustedMiles: Double?
    public var adjustmentReason = ""
    public var issues: [TripIssue] = []
    public var reviewed = false
    public var needsNewSegment = false

    public init(startedAt: Date = Date(), category: TripCategory, purpose: String = "") {
        self.startedAt = startedAt
        self.category = category
        self.purpose = purpose
    }

    public var isActive: Bool { endedAt == nil }
    public var gpsMiles: Double { gpsDistanceMeters / 1609.344 }
    public var miles: Double { adjustedMiles ?? gpsMiles }
    public var needsReview: Bool { !issues.isEmpty && !reviewed }

    public mutating func interrupt(_ reason: RecordingIssue, at date: Date = Date()) {
        let wasInterrupted = needsNewSegment
        needsNewSegment = true
        reviewed = false
        // Avoid a flood of the same issue while an outage is ongoing.
        if issues.last?.reason != reason || !wasInterrupted || !isActive {
            issues.append(TripIssue(date: date, reason: reason))
        }
    }

    public mutating func finish(at date: Date = Date(), lastFixAt: Date? = nil) {
        guard isActive else { return }
        endedAt = max(date, max(samples.last?.timestamp ?? startedAt, startedAt))
        if samples.count < 2 { interrupt(.insufficientGPS, at: endedAt!) }
        else if endedAt!.timeIntervalSince(lastFixAt ?? samples.last!.timestamp) > 60 {
            interrupt(.gpsGap, at: endedAt!)
        }
    }

    /// Distinct coordinate arrays prevent the map from drawing over missing mileage.
    public var routeSegments: [[LocationSample]] {
        var result: [[LocationSample]] = []
        for point in samples {
            if result.isEmpty || !point.connectsToPrevious { result.append([point]) }
            else { result[result.count - 1].append(point) }
        }
        return result
    }
}
