import SwiftUI

struct TripDetailView: View {
    @EnvironmentObject private var store: MileageStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("mileageVehicleName") private var vehicleName = "My vehicle"
    var tripID: UUID
    @State private var category = TripCategory.business
    @State private var purpose = ""
    @State private var notes = ""
    @State private var loaded = false
    @State private var editor: TripDetailEditor?
    @State private var confirmDelete = false
    @State private var savedMessage: String?

    private var trip: Trip? { store.trips.first { $0.id == tripID } }

    var body: some View {
        ScrollView {
            if let trip {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Button { dismiss() } label: {
                            Label("Trips", systemImage: "chevron.left").font(.body).frame(minHeight: 44)
                        }.buttonStyle(.plain)
                        Spacer()
                        Menu {
                            Button("Correct mileage", systemImage: "pencil.line") { editor = .correction }
                                .disabled(store.isReadOnly || trip.isActive)
                            Button("Delete trip", systemImage: "trash", role: .destructive) { confirmDelete = true }
                                .disabled(store.isReadOnly || trip.isActive)
                        } label: { Image(systemName: "ellipsis").font(.title3).frame(width: 44, height: 44) }
                        .accessibilityLabel("Trip actions")
                    }
                    Text("Trip details").font(.system(.largeTitle, weight: .bold))
                    MileageRouteMap(trip: trip, interactive: true)
                        .frame(height: 190)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.mileageSeparator, lineWidth: 1) }
                    tripStats(trip)
                    Divider().overlay(Color.mileageSeparator)
                    VStack(spacing: 14) {
                        endpoint(trip.samples.first, title: "Start location", date: trip.startedAt, isEnd: false)
                        endpoint(trip.samples.last, title: "End location", date: trip.endedAt, isEnd: true)
                    }.padding(.vertical, 2)
                    Divider().overlay(Color.mileageSeparator)
                    MileagePillPicker(options: ["Business", "Personal"], selection: Binding(get: { category.rawValue }, set: { category = TripCategory(rawValue: $0) ?? .business }))
                        .disabled(store.isReadOnly || trip.isActive)
                    VStack(spacing: 0) {
                        detailRow("Purpose", value: purpose.isEmpty ? "Add a purpose" : purpose, icon: "scope") { editor = .purpose }
                        Divider().overlay(Color.mileageSeparator)
                        detailRow("Vehicle", value: vehicleName.isEmpty ? "Add a vehicle" : vehicleName, icon: "car") { editor = .vehicle }
                        Divider().overlay(Color.mileageSeparator)
                        detailRow("Notes", value: notes.isEmpty ? "Add a note" : notes, icon: "doc.text") { editor = .notes }
                        Divider().overlay(Color.mileageSeparator)
                    }
                    if trip.adjustedMiles != nil {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Verified mileage correction", systemImage: "checkmark.circle").font(.caption.weight(.medium))
                            Text("Original GPS: \(trip.gpsMiles.formatted(.number.precision(.fractionLength(2)))) mi · \(trip.adjustmentReason)")
                                .font(.caption).foregroundStyle(Color.mileageSecondary)
                        }
                    }
                    if !trip.issues.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(trip.needsReview ? "This trip needs review" : "Trip reviewed", systemImage: trip.needsReview ? "exclamationmark.circle" : "checkmark.circle")
                                .font(.caption.weight(.medium)).foregroundStyle(trip.needsReview ? Color.mileageWarning : Color.mileageAccentText)
                            ForEach(trip.issues) { issue in Text(issue.reason.rawValue).font(.caption).foregroundStyle(Color.mileageSecondary) }
                            Button("Review or correct mileage") { editor = .correction }
                                .font(.caption.weight(.semibold)).foregroundStyle(Color.mileageAccentText).frame(minHeight: 44)
                                .disabled(store.isReadOnly || trip.isActive)
                        }
                    }
                    if let error = store.storageError { IssueBanner(text: error) }
                    if let savedMessage { Text(savedMessage).font(.caption).foregroundStyle(Color.mileageAccentText).accessibilityAddTraits(.updatesFrequently) }
                    Button("Save changes") { save(trip) }
                        .buttonStyle(MileagePrimaryButtonStyle()).disabled(store.isReadOnly || trip.isActive)
                }
                .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 22)
                .onAppear { if !loaded { load(trip); loaded = true } }
            } else {
                ContentUnavailableView("Trip not found", systemImage: "car")
            }
        }
        .background(Color.mileageBackground).foregroundStyle(Color.mileagePrimary)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editor) { field in
            switch field {
            case .purpose: TripTextEditor(title: "Purpose", text: $purpose, multiline: false)
            case .notes: TripTextEditor(title: "Notes", text: $notes, multiline: true)
            case .vehicle: TripTextEditor(title: "Vehicle", text: $vehicleName, multiline: false, explanation: "This is your default vehicle name for Mileage.")
            case .correction:
                if let trip {
                    TripEditView(trip: edited(trip)).onDisappear { if let updated = self.trip, updated != trip { load(updated) } }
                }
            }
        }
        .onChange(of: category) { _, _ in savedMessage = nil }
        .onChange(of: purpose) { _, _ in savedMessage = nil }
        .onChange(of: notes) { _, _ in savedMessage = nil }
        .confirmationDialog("Delete this trip permanently?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete trip", role: .destructive) { if store.delete(tripID) { dismiss() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func tripStats(_ trip: Trip) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
        return layout {
            stat("\(trip.miles.formatted(.number.precision(.fractionLength(1)))) mi", caption: "Distance")
            if !dynamicTypeSize.isAccessibilitySize { Divider().frame(height: 38).overlay(Color.mileageSeparator) }
            stat(duration(trip), caption: "Duration")
            if !dynamicTypeSize.isAccessibilitySize { Divider().frame(height: 38).overlay(Color.mileageSeparator) }
            stat(trip.startedAt.formatted(.dateTime.month(.abbreviated).day().year()), caption: "\(trip.startedAt.formatted(date: .omitted, time: .shortened)) – \(trip.endedAt?.formatted(date: .omitted, time: .shortened) ?? "Recording")")
        }
    }

    private func stat(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            Text(caption).font(.caption).foregroundStyle(Color.mileageSecondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }

    private func duration(_ trip: Trip) -> String {
        let seconds = max(0, Int((trip.endedAt ?? Date()).timeIntervalSince(trip.startedAt)))
        if seconds < 60 { return "\(seconds) sec" }
        return "\(seconds / 60) min"
    }

    private func endpoint(_ sample: LocationSample?, title: String, date: Date?, isEnd: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Circle().fill(isEnd ? Color.mileageGreen : Color.mileageBackground)
                .overlay(Circle().stroke(isEnd ? Color.mileageAccentText : Color.mileagePrimary, lineWidth: 2))
                .frame(width: 11, height: 11).padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline)
                Text(sample.map { String(format: "%.4f, %.4f", $0.latitude, $0.longitude) } ?? "No GPS point recorded")
                    .font(.caption).foregroundStyle(Color.mileageSecondary)
            }
            Spacer(minLength: 4)
            Text(date?.formatted(date: .omitted, time: .shortened) ?? "—").font(.caption).foregroundStyle(Color.mileageSecondary)
        }.accessibilityElement(children: .combine)
    }

    private func detailRow(_ title: String, value: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title3).frame(width: 28)
                Text(title).font(.subheadline)
                Spacer(minLength: 10)
                Text(value).font(.subheadline).foregroundStyle(Color.mileageSecondary).lineLimit(1)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.mileageSecondary)
            }.frame(minHeight: 54)
        }.buttonStyle(.plain).disabled(store.isReadOnly || trip?.isActive == true)
    }

    private func edited(_ original: Trip) -> Trip {
        var updated = original
        updated.category = category; updated.purpose = purpose; updated.notes = notes
        return updated
    }
    private func load(_ trip: Trip) { category = trip.category; purpose = trip.purpose; notes = trip.notes }
    private func save(_ trip: Trip) { if store.update(edited(trip)) { savedMessage = "Changes saved on this iPhone." } }
}

private enum TripDetailEditor: String, Identifiable {
    case purpose, notes, vehicle, correction
    var id: String { rawValue }
}

struct TripTextEditor: View {
    @Environment(\.dismiss) private var dismiss
    var title: String
    @Binding var text: String
    var multiline: Bool
    var explanation: String? = nil
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if multiline { TextField(title, text: $draft, axis: .vertical).lineLimit(5...10) }
                    else { TextField(title, text: $draft) }
                } footer: { if let explanation { Text(explanation) } }
                .listRowBackground(Color.mileageCard)
            }
            .scrollContentBackground(.hidden).background(Color.mileageBackground)
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { text = draft.trimmingCharacters(in: .whitespacesAndNewlines); dismiss() } }
            }
            .onAppear { draft = text }
        }
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
        formatter.locale = .current; formatter.numberStyle = .decimal; formatter.isLenient = false
        let text = milesText.trimmingCharacters(in: .whitespacesAndNewlines)
        let pieces = text.components(separatedBy: formatter.decimalSeparator ?? ".")
        guard pieces.count <= 2, pieces.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let value = formatter.number(from: text)?.doubleValue, value.isFinite, value >= 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip details") {
                    Picker("Category", selection: $trip.category) { ForEach(TripCategory.allCases) { Text($0.rawValue).tag($0) } }
                    TextField("Purpose", text: $trip.purpose)
                    TextField("Notes", text: $trip.notes, axis: .vertical).lineLimit(3...6)
                }.listRowBackground(Color.mileageCard)
                Section {
                    Toggle("Use a verified mileage correction", isOn: $useCorrection)
                    if useCorrection {
                        TextField("Total trip miles", text: $milesText).keyboardType(.decimalPad)
                        TextField("Reason / source (required)", text: $trip.adjustmentReason, axis: .vertical)
                    }
                } header: { Text("Mileage") } footer: {
                    Text("Original GPS mileage and route are kept. Enter the complete trip total and a source used to verify it.")
                }.listRowBackground(Color.mileageCard)
                if !trip.issues.isEmpty {
                    Section { Toggle("I reviewed the route and mileage", isOn: $trip.reviewed) }
                    footer: { Text("Review does not reconstruct a missing route.") }
                    .listRowBackground(Color.mileageCard)
                }
                if let error { Text(error).foregroundStyle(Color.mileageWarning).listRowBackground(Color.mileageWarningSurface) }
            }
            .scrollContentBackground(.hidden).background(Color.mileageBackground).foregroundStyle(Color.mileagePrimary)
            .tint(Color.mileageAccentText).scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit trip").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if useCorrection {
                            guard let miles = correctedMiles, !trip.adjustmentReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { error = "Enter valid miles and explain the source of your correction."; return }
                            trip.adjustedMiles = miles
                        } else { trip.adjustedMiles = nil; trip.adjustmentReason = "" }
                        if store.update(trip) { dismiss() } else { error = store.storageError ?? "This trip cannot be edited." }
                    }
                }
            }
            .onAppear {
                useCorrection = trip.adjustedMiles != nil
                if let miles = trip.adjustedMiles { milesText = miles.formatted(.number.grouping(.never).precision(.fractionLength(0...3))) }
            }
        }
        .preferredColorScheme(MileageAppearance(rawValue: appearance)?.colorScheme)
    }
}
