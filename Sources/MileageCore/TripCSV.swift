import Foundation

public enum TripCSV {
    public static func export(_ trips: [Trip]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var rows = [["Trip ID", "Started (UTC)", "Ended (UTC)", "Category", "Purpose", "Miles",
                     "GPS miles", "Adjusted miles", "Adjustment reason", "Notes", "Review status",
                     "Recording issues", "Start latitude", "Start longitude", "End latitude", "End longitude"]]
        for trip in trips.filter({ !$0.isActive }).sorted(by: { $0.startedAt < $1.startedAt }) {
            rows.append([
                trip.id.uuidString, formatter.string(from: trip.startedAt),
                trip.endedAt.map(formatter.string(from:)) ?? "", trip.category.rawValue,
                trip.purpose, number(trip.miles), number(trip.gpsMiles),
                trip.adjustedMiles.map { number($0) } ?? "", trip.adjustmentReason, trip.notes,
                trip.needsReview ? "Needs review" : (trip.reviewed ? "Reviewed" : "No issues flagged"),
                trip.issues.map { $0.reason.rawValue }.joined(separator: "; "),
                trip.samples.first.map { number($0.latitude, digits: 6) } ?? "",
                trip.samples.first.map { number($0.longitude, digits: 6) } ?? "",
                trip.samples.last.map { number($0.latitude, digits: 6) } ?? "",
                trip.samples.last.map { number($0.longitude, digits: 6) } ?? ""
            ])
        }
        return rows.map { $0.map(cell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    private static func number(_ value: Double, digits: Int = 3) -> String {
        String(format: "%.*f", locale: Locale(identifier: "en_US_POSIX"), digits, value)
    }

    private static func cell(_ value: String) -> String {
        // Quoting alone doesn't stop spreadsheet formula injection.
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let unsafe = trimmed.first.map { "=+-@".contains($0) } ?? false
        // Negative numeric coordinates are safe numbers; user text is neutralized.
        let isNumber = Double(trimmed).map { $0.isFinite } ?? false
        let safe = unsafe && !isNumber ? "'" + value : value
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
