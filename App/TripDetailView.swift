import SwiftUI
import MapKit

struct TripDetailView: View {
    @EnvironmentObject private var store: MileageStore
    @Environment(\.dismiss) private var dismiss
    var tripID: UUID
    @State private var editTrip: Trip?
    @State private var confirmDelete = false

    private var trip: Trip? { store.trips.first { $0.id == tripID } }

    var body: some View {
        Group {
            if let trip {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if trip.samples.isEmpty {
                            ContentUnavailableView("No GPS route recorded", systemImage: "map",
                                                   description: Text("You can enter a verified mileage correction below."))
                        } else { RouteMap(trip: trip).frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 24)) }
                        MileageCard {
                            HStack(alignment: .firstTextBaseline) {
                                Text(trip.miles, format: .number.precision(.fractionLength(2)))
                                    .font(.system(size: 48, weight: .semibold, design: .rounded)).monospacedDigit()
                                Text("miles").foregroundStyle(.secondary)
                            }
                            Label(trip.category.rawValue, systemImage: trip.category == .business ? "briefcase" : "car")
                                .foregroundStyle(.mileageGreen)
                            Text(trip.purpose.isEmpty ? "No purpose added" : trip.purpose).font(.headline)
                            LabeledContent("Started", value: trip.startedAt.formatted(date: .abbreviated, time: .shortened))
                            if let end = trip.endedAt {
                                LabeledContent("Ended", value: end.formatted(date: .abbreviated, time: .shortened))
                            }
                            if trip.adjustedMiles != nil {
                                LabeledContent("GPS miles", value: trip.gpsMiles.formatted(.number.precision(.fractionLength(2))))
                                Text("Correction: \(trip.adjustmentReason)").font(.subheadline).foregroundStyle(.secondary)
                            }
                            if !trip.notes.isEmpty { Text(trip.notes).font(.subheadline) }
                        }
                        if !trip.issues.isEmpty {
                            MileageCard {
                                Label(trip.needsReview ? "Review this trip" : "Reviewed trip",
                                      systemImage: trip.needsReview ? "exclamationmark.triangle" : "checkmark.seal")
                                    .foregroundStyle(trip.needsReview ? Color.orange : Color.mileageGreen).font(.headline)
                                Text("Missing sections are excluded from GPS mileage. Compare with your odometer or another record before using this total.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                ForEach(trip.issues) { issue in
                                    HStack(alignment: .top) {
                                        Text(issue.reason.rawValue)
                                        Spacer()
                                        Text(issue.date, format: .dateTime.hour().minute()).foregroundStyle(.secondary)
                                    }.font(.caption)
                                }
                            }
                        }
                        if let error = store.storageError { IssueBanner(text: error) }
                        Button("Edit details or correct mileage") { editTrip = trip }
                            .buttonStyle(.borderedProminent).foregroundStyle(.black).frame(maxWidth: .infinity)
                            .disabled(store.isReadOnly || trip.isActive)
                        Button("Delete trip", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity).padding(.vertical, 8).disabled(store.isReadOnly || trip.isActive)
                    }.padding(20)
                }
            } else { ContentUnavailableView("Trip not found", systemImage: "car") }
        }
        .background(Color.mileageBackground)
        .navigationTitle("Trip details").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editTrip) { TripEditView(trip: $0) }
        .confirmationDialog("Delete this trip permanently?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete trip", role: .destructive) { if store.delete(tripID) { dismiss() } }
        }
    }
}

private struct RouteMap: View {
    var trip: Trip
    var body: some View {
        Map {
            ForEach(Array(trip.routeSegments.enumerated()), id: \.offset) { _, segment in
                if segment.count > 1 {
                    MapPolyline(coordinates: segment.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
                        .stroke(.green, lineWidth: 5)
                }
            }
            if let first = trip.samples.first {
                Marker("Start", systemImage: "flag.fill", coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)).tint(.green)
            }
            if let last = trip.samples.last {
                Marker("End", systemImage: "flag.checkered", coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)).tint(.orange)
            }
        }
        .mapControls { MapCompass(); MapScaleView() }
        .accessibilityLabel("Recorded route. Gaps are not connected.")
    }
}

struct TripEditView: View {
    @EnvironmentObject private var store: MileageStore
    @Environment(\.dismiss) private var dismiss
    @State var trip: Trip
    @State private var useCorrection = false
    @State private var milesText = ""
    @State private var error: String?

    private var correctedMiles: Double? {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.isLenient = false
        let text = milesText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Require a full numeric input; NumberFormatter can accept a numeric prefix.
        let separator = formatter.decimalSeparator ?? "."
        let pieces = text.components(separatedBy: separator)
        guard pieces.count <= 2, pieces.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let number = formatter.number(from: text)?.doubleValue, number.isFinite, number >= 0 else { return nil }
        return number
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip details") {
                    Picker("Category", selection: $trip.category) {
                        ForEach(TripCategory.allCases) { Text($0.rawValue).tag($0) }
                    }
                    TextField("Purpose", text: $trip.purpose)
                    TextField("Notes", text: $trip.notes, axis: .vertical).lineLimit(3...6)
                }
                Section {
                    Toggle("Use a verified mileage correction", isOn: $useCorrection)
                    if useCorrection {
                        TextField("Total trip miles", text: $milesText).keyboardType(.decimalPad)
                        TextField("Reason / source (required)", text: $trip.adjustmentReason, axis: .vertical)
                    }
                } header: { Text("Mileage") } footer: {
                    Text("The GPS measurement and original route are kept. Enter the full trip total, not just the missing miles.")
                }
                if !trip.issues.isEmpty {
                    Section {
                        Toggle("I reviewed the route and mileage", isOn: $trip.reviewed)
                    } footer: { Text("Review does not reconstruct a missing route.") }
                }
                if let error { Section { Text(error).foregroundStyle(.orange) } }
            }
            .navigationTitle("Edit trip").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if useCorrection {
                            guard let miles = correctedMiles, !trip.adjustmentReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                error = "Enter valid miles and explain the source of your correction."
                                return
                            }
                            trip.adjustedMiles = miles
                        } else { trip.adjustedMiles = nil; trip.adjustmentReason = "" }
                        if store.update(trip) { dismiss() } else { error = store.storageError ?? "This trip cannot be edited." }
                    }
                }
            }
            .onAppear {
                useCorrection = trip.adjustedMiles != nil
                if let miles = trip.adjustedMiles {
                    milesText = miles.formatted(.number.grouping(.never).precision(.fractionLength(0...3)))
                }
            }
        }
    }
}
