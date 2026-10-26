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
}
