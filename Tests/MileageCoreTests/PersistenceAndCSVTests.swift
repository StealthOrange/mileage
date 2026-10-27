import XCTest
@testable import MileageCore

final class PersistenceAndCSVTests: XCTestCase {
    private var directory: URL!
    private var repository: TripRepository!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        repository = TripRepository(fileURL: directory.appendingPathComponent("trips.json"))
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }

    func testFreshInstallHasNoTrips() throws { XCTAssertEqual(try repository.load(), []) }

    func testRoundTripKeepsActiveTripRouteAndExactTimestamps() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000.12345)
        var trip = Trip(startedAt: date, category: .business, purpose: "Facility visits")
        RouteRecorder.append(LocationSample(latitude: 29.7, longitude: -95.3, accuracy: 5, timestamp: date), to: &trip)
        try repository.save([trip])
        XCTAssertEqual(try repository.load(), [trip])
        XCTAssertTrue(try repository.load()[0].isActive)
    }

    func testCorruptArchiveIsNotReplacedOnLoad() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let original = Data("corrupt file that must survive".utf8)
        try original.write(to: repository.fileURL)
        XCTAssertThrowsError(try repository.load())
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), original)
    }

    func testUnknownArchiveVersionIsRejected() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{\"version\":99,\"trips\":[]}".utf8).write(to: repository.fileURL)
        XCTAssertThrowsError(try repository.load())
    }

    func testRejectsMultipleActiveTripsAndInvalidCorrectionBeforeWriting() throws {
        let trip = Trip(category: .business)
        try repository.save([trip])
        XCTAssertThrowsError(try repository.save([trip, Trip(category: .personal)]))
        XCTAssertEqual(try repository.load(), [trip])
        var invalid = trip
        invalid.adjustedMiles = -1
        XCTAssertThrowsError(try repository.save([invalid]))
        XCTAssertEqual(try repository.load(), [trip])
    }

    func testFailedSaveLeavesExistingFileIntact() throws {
        let trip = Trip(category: .business)
        try repository.save([trip])
        var invalid = trip
        invalid.gpsDistanceMeters = .infinity
        XCTAssertThrowsError(try repository.save([invalid]))
        XCTAssertEqual(try repository.load(), [trip])
    }

    func testCSVQuotesMultilineFieldsAndNeutralizesFormulas() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var trip = Trip(startedAt: start, category: .business, purpose: "  =HYPERLINK(\"bad\")")
        trip.notes = "Line one, \"quoted\"\nLine two"
        trip.adjustedMiles = 12.345
        trip.adjustmentReason = "Odometer"
        trip.finish(at: start.addingTimeInterval(120))
        let csv = TripCSV.export([trip, Trip(category: .personal)])
        XCTAssertTrue(csv.contains("\"'  =HYPERLINK(\"\"bad\"\")\""))
        XCTAssertTrue(csv.contains("\"Line one, \"\"quoted\"\"\nLine two\""))
        XCTAssertTrue(csv.contains("\"12.345\""))
        XCTAssertTrue(csv.contains("2023-11-14T22:13:20.000Z"))
        XCTAssertEqual(csv.components(separatedBy: "\r\n").count, 3, "Header, one completed trip, trailing newline")
    }

    func testCSVHasStableUSDecimalsAndKeepsReviewWarnings() {
        var trip = Trip(category: .personal)
        trip.adjustedMiles = 1234.567
        trip.finish()
        let csv = TripCSV.export([trip])
        XCTAssertTrue(csv.contains("\"1234.567\""))
        XCTAssertTrue(csv.contains("\"Needs review\""))
        XCTAssertTrue(csv.contains("Not enough GPS points"))
    }

    func testManualTripPersistsVerifiedTotalWithoutInventingGPS() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let trip = try Trip.manual(category: .business, purpose: "  Client visit  ", startedAt: start,
                                   endedAt: start.addingTimeInterval(1800), miles: 18.7,
                                   reason: "  Odometer: 12000.0 to 12018.7  ")
        let active = Trip(startedAt: start.addingTimeInterval(3600), category: .personal)
        try repository.save([active, trip])

        let saved = try repository.load()
        XCTAssertEqual(saved, [active, trip])
        XCTAssertFalse(trip.isActive)
        XCTAssertEqual(trip.miles, 18.7)
        XCTAssertEqual(trip.gpsMiles, 0)
        XCTAssertTrue(trip.samples.isEmpty)
        XCTAssertEqual(trip.routeSegments, [])
        XCTAssertEqual(trip.purpose, "Client visit")
        XCTAssertEqual(trip.adjustmentReason, "Odometer: 12000.0 to 12018.7")
        XCTAssertTrue(trip.reviewed)
        XCTAssertFalse(trip.needsReview)
        XCTAssertTrue(trip.notes.contains("No GPS route recorded"))

        let csv = TripCSV.export(saved)
        XCTAssertTrue(csv.contains("\"18.700\",\"0.000\",\"18.700\""))
        XCTAssertTrue(csv.contains("\"Reviewed\""))
        XCTAssertTrue(csv.contains("Odometer: 12000.0 to 12018.7"))
    }

    func testManualTripRejectsInvalidTotalsDatesAndMissingSource() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for miles in [-1, Double.nan, Double.infinity] {
            XCTAssertThrowsError(try Trip.manual(category: .personal, purpose: "", startedAt: start,
                                                 endedAt: start, miles: miles, reason: "Odometer"))
        }
        XCTAssertThrowsError(try Trip.manual(category: .personal, purpose: "", startedAt: start,
                                             endedAt: start.addingTimeInterval(-1), miles: 1, reason: "Odometer"))
        XCTAssertThrowsError(try Trip.manual(category: .personal, purpose: "", startedAt: start,
                                             endedAt: Date(timeIntervalSinceReferenceDate: .infinity),
                                             miles: 1, reason: "Odometer"))
        XCTAssertThrowsError(try Trip.manual(category: .personal, purpose: "", startedAt: start,
                                             endedAt: start, miles: 1, reason: " \n "))
        XCTAssertNoThrow(try Trip.manual(category: .personal, purpose: "", startedAt: start,
                                         endedAt: start, miles: 0, reason: "Odometer unchanged"))
    }

    func testUserPauseIssueSurvivesAnArchiveRoundTrip() throws {
        var trip = Trip(category: .business)
        trip.interrupt(.userPaused)
        try repository.save([trip])
        let saved = try XCTUnwrap(repository.load().first)
        XCTAssertEqual(saved.issues.first?.reason, .userPaused)
        XCTAssertTrue(saved.needsReview)
        XCTAssertTrue(saved.needsNewSegment)
    }

    func testFinishingAnIntentionallyPausedTripDoesNotInventGPSLoss() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var trip = Trip(startedAt: start, category: .business)
        RouteRecorder.append(LocationSample(latitude: 29.7, longitude: -95.3, accuracy: 5,
                                             timestamp: start), to: &trip)
        let lastFix = start.addingTimeInterval(10)
        RouteRecorder.append(LocationSample(latitude: 29.7005, longitude: -95.3, accuracy: 5,
                                             timestamp: lastFix), to: &trip)
        trip.interrupt(.userPaused, at: start.addingTimeInterval(20))
        trip.finish(at: start.addingTimeInterval(300), lastFixAt: lastFix)

        XCTAssertEqual(trip.issues.map(\.reason), [.userPaused])
        XCTAssertFalse(trip.isActive)
        XCTAssertTrue(trip.needsReview)
    }
}
