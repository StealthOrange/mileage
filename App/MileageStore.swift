import Foundation
import Combine

@MainActor
final class MileageStore: ObservableObject {
    @Published private(set) var trips: [Trip] = []
    @Published private(set) var storageError: String?
    @Published private(set) var isReadOnly = false
    let repository: TripRepository

    var activeTrip: Trip? { trips.first(where: \.isActive) }
    var completedTrips: [Trip] { trips.filter { !$0.isActive } }

    init() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        repository = TripRepository(fileURL: root.appendingPathComponent("Mileage/trips.json"))
        do {
            trips = try repository.load()
            if activeTrip != nil { _ = interrupt(.appRestarted) }
        } catch {
            isReadOnly = true
            storageError = "Your saved file could not be opened. It has not been replaced. \(error.localizedDescription)"
        }
    }

    @discardableResult
    func start(category: TripCategory, purpose: String) -> Bool {
        guard activeTrip == nil else { return false }
        var proposed = trips
        proposed.insert(Trip(category: category, purpose: purpose), at: 0)
        return commit(proposed)
    }

    @discardableResult
    func append(_ samples: [LocationSample]) -> Bool {
        guard let index = trips.firstIndex(where: \.isActive) else { return false }
        var proposed = trips
        var changed = false
        for sample in samples.sorted(by: { $0.timestamp < $1.timestamp }) {
            if RouteRecorder.append(sample, to: &proposed[index]) { changed = true }
        }
        return !changed || commit(proposed)
    }

    @discardableResult
    func finish(lastFixAt: Date?) -> Bool {
        guard let index = trips.firstIndex(where: \.isActive) else { return false }
        var proposed = trips
        proposed[index].finish(lastFixAt: lastFixAt)
        return commit(proposed)
    }

    @discardableResult
    func interrupt(_ reason: RecordingIssue) -> Bool {
        guard let index = trips.firstIndex(where: \.isActive) else { return false }
        var proposed = trips
        proposed[index].interrupt(reason)
        return commit(proposed)
    }

    func update(_ trip: Trip) -> Bool {
        // Editing a live snapshot could overwrite newer GPS samples.
        guard !trip.isActive, let index = trips.firstIndex(where: { $0.id == trip.id }),
              !trips[index].isActive else { return false }
        var proposed = trips
        proposed[index] = trip
        return commit(proposed)
    }

    func delete(_ id: UUID) -> Bool {
        guard activeTrip?.id != id else { return false }
        return commit(trips.filter { $0.id != id })
    }

    func csvURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Mileage-trips.csv")
        try TripCSV.export(trips).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func backupURL() throws -> URL {
        // Export the ORIGINAL file even if decoding failed, so recovery is possible.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Mileage-backup.json")
        let data = try Data(contentsOf: repository.fileURL)
        try data.write(to: url, options: .atomic)
        return url
    }

    @discardableResult
    private func commit(_ proposed: [Trip]) -> Bool {
        guard !isReadOnly else { return false }
        do {
            try repository.save(proposed)
            trips = proposed
            storageError = nil
            return true
        } catch {
            storageError = "Mileage could not save your trip. Recording has stopped to protect your records. \(error.localizedDescription)"
            return false
        }
    }
}
