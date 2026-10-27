import SwiftUI
import MapKit

struct TripDetailView: View {
    @EnvironmentObject private var store: MileageStore
    @Environment(\.dismiss) private var dismiss
    var tripID: UUID
    @State private var editTrip: Trip?
    @State private var confirmDelete = false
    @ScaledMetric(relativeTo: .largeTitle) private var mileageSize: CGFloat = MileageTokens.Typography.detailMetric

    private var trip: Trip? { store.trips.first { $0.id == tripID } }

    var body: some View {
        Group {
            if let trip {
                ScrollView {
                    VStack(alignment: .leading, spacing: MileageTokens.Space.xl) {
                        if trip.samples.isEmpty {
                            ContentUnavailableView("No GPS route recorded", systemImage: "map",
                                                   description: Text("You can enter a verified mileage correction below."))
                            .padding(.vertical, MileageTokens.Space.lg)
                        } else {
                            RouteMap(trip: trip)
                                .frame(height: 240)
                                .clipShape(RoundedRectangle(cornerRadius: MileageTokens.Radius.card))
                                .overlay {
                                    RoundedRectangle(cornerRadius: MileageTokens.Radius.card)
                                        .strokeBorder(Color.mileageSeparator, lineWidth: 1)
                                }
                        }
                        MileageCard {
                            Label(trip.category.rawValue, systemImage: trip.category == .business ? "briefcase" : "car")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.mileageGreen)
                            HStack(alignment: .firstTextBaseline) {
                                Text(trip.miles, format: .number.precision(.fractionLength(2)))
                                    .font(.system(size: mileageSize, weight: .semibold)).monospacedDigit()
                                    .minimumScaleFactor(0.6)
                                Text("miles")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.mileageSecondary)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(trip.miles.formatted(.number.precision(.fractionLength(2)))) miles")
                            Text(trip.purpose.isEmpty ? "\(trip.category.rawValue) trip" : trip.purpose)
                                .font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                            Divider().overlay(Color.mileageSeparator)
                            VStack(spacing: MileageTokens.Space.md) {
                                LabeledContent("Started", value: trip.startedAt.formatted(date: .abbreviated, time: .shortened))
                                if let end = trip.endedAt {
                                    LabeledContent("Ended", value: end.formatted(date: .abbreviated, time: .shortened))
                                }
                                if trip.adjustedMiles != nil {
                                    LabeledContent("Original GPS miles", value: trip.gpsMiles.formatted(.number.precision(.fractionLength(2))))
                                }
                            }
                            .font(.subheadline)
                            if trip.adjustedMiles != nil {
                                Label("Mileage corrected", systemImage: "checkmark.circle")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.mileageGreen)
                                Text(trip.adjustmentReason)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.mileageSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if !trip.notes.isEmpty {
                                Divider().overlay(Color.mileageSeparator)
                                Text("Notes").font(.subheadline.weight(.semibold))
                                Text(trip.notes)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.mileageSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if !trip.issues.isEmpty {
                            MileageCard {
                                Label(trip.needsReview ? "Review this trip" : "Reviewed trip",
                                      systemImage: trip.needsReview ? "exclamationmark.triangle" : "checkmark.seal")
                                    .foregroundStyle(trip.needsReview ? Color.mileageWarning : Color.mileageGreen).font(.headline)
                                Text("Missing sections are excluded from GPS mileage. Compare with your odometer or another record before using this total.")
                                    .font(.subheadline).foregroundStyle(Color.mileageSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                ForEach(trip.issues) { issue in
                                    HStack(alignment: .top) {
                                        Text(issue.reason.rawValue)
                                        Spacer()
                                        Text(issue.date, format: .dateTime.hour().minute()).foregroundStyle(Color.mileageSecondary)
                                    }.font(.caption)
                                }
                            }
                        }
                        if let error = store.storageError { IssueBanner(text: error) }
                        Button { editTrip = trip } label: {
                            Label("Edit trip", systemImage: "pencil")
                        }
                            .buttonStyle(MileagePrimaryButtonStyle())
                            .accessibilityHint("Change purpose, notes, category, or enter a verified mileage correction")
                            .disabled(store.isReadOnly || trip.isActive)
                        Button("Delete trip", role: .destructive) { confirmDelete = true }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.mileageDanger)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .disabled(store.isReadOnly || trip.isActive)
                    }.padding(MileageTokens.Space.xl)
                }
            } else { ContentUnavailableView("Trip not found", systemImage: "car") }
        }
        .background(Color.mileageBackground)
        .foregroundStyle(Color.mileagePrimary)
        .navigationTitle("Trip details").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.mileageBackground, for: .navigationBar)
        .toolbar(.visible, for: .navigationBar)
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
                        .stroke(Color.mileageGreen, lineWidth: 5)
                }
            }
            if let first = trip.samples.first {
                Marker("Start", systemImage: "flag.fill", coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)).tint(Color.mileageGreen)
            }
            if let last = trip.samples.last {
                Marker("End", systemImage: "flag.checkered", coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)).tint(Color.mileageWarning)
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
    @AppStorage("mileageAppearance") private var appearance = MileageAppearance.system.rawValue

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
                        .textInputAutocapitalization(.sentences)
                    TextField("Notes", text: $trip.notes, axis: .vertical).lineLimit(3...6)
                }
                .listRowBackground(Color.mileageCard)
                Section {
                    Toggle("Use a verified mileage correction", isOn: $useCorrection)
                    if useCorrection {
                        TextField("Total trip miles", text: $milesText).keyboardType(.decimalPad)
                        TextField("Reason / source (required)", text: $trip.adjustmentReason, axis: .vertical)
                    }
                } header: { Text("Mileage") } footer: {
                    Text("The original GPS measurement and route are kept. Enter the full trip total and the source you used to verify it.")
                }
                .listRowBackground(Color.mileageCard)
                if !trip.issues.isEmpty {
                    Section {
                        Toggle("I reviewed the route and mileage", isOn: $trip.reviewed)
                    } footer: { Text("Review does not reconstruct a missing route.") }
                    .listRowBackground(Color.mileageCard)
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(Color.mileageWarning) }
                        .listRowBackground(Color.mileageWarningSurface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.mileageBackground)
            .foregroundStyle(Color.mileagePrimary)
            .tint(Color.mileageGreen)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit trip").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.mileageBackground, for: .navigationBar)
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
        .preferredColorScheme(MileageAppearance(rawValue: appearance)?.colorScheme)
    }
}
