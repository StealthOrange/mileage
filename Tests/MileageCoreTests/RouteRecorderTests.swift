import XCTest
@testable import MileageCore

final class RouteRecorderTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    func point(_ latitude: Double = 29.7604, _ longitude: Double = -95.3698,
               seconds: Double = 0, accuracy: Double = 5) -> LocationSample {
        LocationSample(latitude: latitude, longitude: longitude, accuracy: accuracy,
                       timestamp: start.addingTimeInterval(seconds))
    }

    func testMeasuresKnownDistanceInMiles() {
        var trip = Trip(startedAt: start, category: .business)
        XCTAssertTrue(RouteRecorder.append(point(), to: &trip))
        XCTAssertTrue(RouteRecorder.append(point(29.7614, seconds: 10), to: &trip))
        XCTAssertEqual(trip.gpsDistanceMeters, 111.195, accuracy: 0.01)
        XCTAssertEqual(trip.miles, 0.06909, accuracy: 0.0001)
        XCTAssertEqual(trip.routeSegments.count, 1)
    }

    func testStationaryNoiseDoesNotInflateDistance() {
        var trip = Trip(startedAt: start, category: .personal)
        RouteRecorder.append(point(), to: &trip)
        for second in 1...30 {
            RouteRecorder.append(point(29.76041, seconds: Double(second)), to: &trip)
        }
        XCTAssertEqual(trip.gpsDistanceMeters, 0)
        XCTAssertEqual(trip.samples.count, 1)
    }

    func testRejectsWeakInvalidDuplicateStaleAndOutOfOrderFixes() {
        var trip = Trip(startedAt: start, category: .business)
        XCTAssertFalse(RouteRecorder.append(point(seconds: -1), to: &trip))
        XCTAssertFalse(RouteRecorder.append(point(100), to: &trip))
        XCTAssertFalse(RouteRecorder.append(point(.nan), to: &trip))
        XCTAssertFalse(RouteRecorder.append(point(accuracy: 100), to: &trip))
        XCTAssertFalse(RouteRecorder.append(point(accuracy: -1), to: &trip))
        RouteRecorder.append(point(seconds: 10), to: &trip)
        XCTAssertFalse(RouteRecorder.append(point(29.7614, seconds: 10), to: &trip))
        XCTAssertFalse(RouteRecorder.append(point(29.7614, seconds: 5), to: &trip))
        XCTAssertEqual(trip.samples.count, 1)
    }

    func testRejectsTeleportWithoutPoisoningAnchor() {
        var trip = Trip(startedAt: start, category: .business)
        RouteRecorder.append(point(), to: &trip)
        XCTAssertFalse(RouteRecorder.append(point(30.5, seconds: 2), to: &trip))
        XCTAssertTrue(RouteRecorder.append(point(29.7614, seconds: 10), to: &trip))
        XCTAssertEqual(trip.gpsDistanceMeters, 111.195, accuracy: 0.01)
    }

    func testLongGapStartsNewSegmentWithoutInventingMiles() {
        var trip = Trip(startedAt: start, category: .business)
        RouteRecorder.append(point(), to: &trip)
        RouteRecorder.append(point(29.7614, seconds: 10), to: &trip)
        RouteRecorder.append(point(30.5, seconds: 300), to: &trip)
        XCTAssertEqual(trip.gpsDistanceMeters, 111.195, accuracy: 0.01)
        XCTAssertFalse(trip.samples.last!.connectsToPrevious)
        XCTAssertEqual(trip.routeSegments.count, 2)
        XCTAssertTrue(trip.needsReview)
        RouteRecorder.append(point(30.501, seconds: 310), to: &trip)
        XCTAssertEqual(trip.gpsDistanceMeters, 222.39, accuracy: 0.02)
    }

    func testExplicitInterruptionDoesNotBridgeEvenAShortGap() {
        var trip = Trip(startedAt: start, category: .business)
        RouteRecorder.append(point(), to: &trip)
        trip.interrupt(.permissionChanged, at: start.addingTimeInterval(1))
        RouteRecorder.append(point(29.7614, seconds: 10), to: &trip)
        XCTAssertEqual(trip.miles, 0)
        XCTAssertEqual(trip.routeSegments.count, 2)
    }

    func testFinishingWithoutGPSFlagsReviewAndPreventsFurtherRecording() {
        var trip = Trip(startedAt: start, category: .business)
        trip.finish(at: start.addingTimeInterval(10))
        XCTAssertTrue(trip.needsReview)
        XCTAssertFalse(RouteRecorder.append(point(seconds: 11), to: &trip))
        XCTAssertEqual(trip.endedAt, start.addingTimeInterval(10))
    }

    func testMissingFinalSectionIsFlagged() {
        var trip = Trip(startedAt: start, category: .business)
        RouteRecorder.append(point(), to: &trip)
        RouteRecorder.append(point(29.7614, seconds: 10), to: &trip)
        trip.finish(at: start.addingTimeInterval(100))
        XCTAssertTrue(trip.needsReview)
        XCTAssertEqual(trip.issues.last?.reason, .gpsGap)
    }

    func testRecentStationaryFixPreventsFalseEndGap() {
        var trip = Trip(startedAt: start, category: .business)
        RouteRecorder.append(point(), to: &trip)
        RouteRecorder.append(point(29.7614, seconds: 10), to: &trip)
        trip.finish(at: start.addingTimeInterval(100), lastFixAt: start.addingTimeInterval(99))
        XCTAssertFalse(trip.needsReview)
    }

    func testCorrectionPreservesGPSAndNewInterruptionRequiresReviewAgain() {
        var trip = Trip(startedAt: start, category: .business)
        RouteRecorder.append(point(), to: &trip)
        RouteRecorder.append(point(29.7614, seconds: 10), to: &trip)
        let original = trip.gpsMiles
        trip.adjustedMiles = 5.2
        trip.adjustmentReason = "Odometer"
        trip.reviewed = true
        trip.interrupt(.gpsGap)
        XCTAssertEqual(trip.miles, 5.2)
        XCTAssertEqual(trip.gpsMiles, original)
        XCTAssertTrue(trip.needsReview)
    }
}
