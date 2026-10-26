import Foundation

public enum RepositoryError: LocalizedError {
    case unsupportedVersion
    case invalidTrips
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "This trip file uses a newer format. Update Mileage before opening it."
        case .invalidTrips: return "The trip file is invalid. The original file has been preserved."
        }
    }
}

public struct TripArchive: Codable {
    public var version = 1
    public var trips: [Trip]
    public init(trips: [Trip]) { self.trips = trips }
}

public final class TripRepository {
    public let fileURL: URL
    public init(fileURL: URL) { self.fileURL = fileURL }

    public func load() throws -> [Trip] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let archive = try JSONDecoder().decode(TripArchive.self, from: Data(contentsOf: fileURL))
        guard archive.version == 1 else { throw RepositoryError.unsupportedVersion }
        try Self.validate(archive.trips)
        return archive.trips
    }

    public func save(_ trips: [Trip]) throws {
        try Self.validate(trips)
        let data = try JSONEncoder().encode(TripArchive(trips: trips))
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        // This class allows locked-screen writes after the first unlock after boot.
        // Complete protection would make saves fail as soon as the phone locks.
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: fileURL, options: .atomic)
        #endif
    }

    private static func validate(_ trips: [Trip]) throws {
        guard Set(trips.map(\.id)).count == trips.count,
              trips.filter(\.isActive).count <= 1,
              trips.allSatisfy({ trip in
                  trip.gpsDistanceMeters.isFinite && trip.gpsDistanceMeters >= 0 &&
                  (trip.adjustedMiles.map { $0.isFinite && $0 >= 0 } ?? true) &&
                  (trip.endedAt.map { $0 >= trip.startedAt } ?? true) &&
                  trip.samples.allSatisfy(\.isValid)
              }) else { throw RepositoryError.invalidTrips }
    }
}
