import SwiftUI
import UIKit

struct TripHistoryView: View {
    @EnvironmentObject private var store: MileageStore
    @Environment(\.dismiss) private var dismiss
    private var showsBack: Bool
    @State private var filter: String
    @State private var selectedMonth: Date
    @State private var query = ""
    @State private var showsSearch = false
    @State private var showsAddTrip = false

    init(initialFilter: String = "All", initialMonth: Date = Date(), showsBack: Bool = false) {
        self.showsBack = showsBack
        _filter = State(initialValue: initialFilter)
        _selectedMonth = State(initialValue: initialMonth)
    }

    private var monthlyTrips: [Trip] {
        store.completedTrips.filter { Calendar.current.isDate($0.startedAt, equalTo: selectedMonth, toGranularity: .month) }
    }

    private var filtered: [Trip] {
        monthlyTrips.filter {
            (filter == "All" || $0.category.rawValue == filter || (filter == "Review" && $0.needsReview)) &&
            (query.isEmpty || "\($0.purpose) \($0.notes)".localizedCaseInsensitiveContains(query))
        }.sorted { $0.startedAt > $1.startedAt }
    }

    private var groupedTrips: [(day: Date, trips: [Trip])] {
        let groups = Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.startedAt) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        if showsBack {
            content
        } else {
            NavigationStack { content }
        }
    }

    private var content: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if showsBack {
                        Button { dismiss() } label: { Label("Reports", systemImage: "chevron.left").frame(minHeight: 44) }.buttonStyle(.plain)
                    }
                    HStack {
                        Text("Trips").font(.system(.largeTitle, weight: .bold))
                        Spacer()
                        Button { withAnimation { showsSearch.toggle() } } label: {
                            Image(systemName: "magnifyingglass").font(.title3).frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(showsSearch ? "Hide search" : "Search trips")
                    }
                    if showsSearch {
                        TextField("Search purpose or notes", text: $query)
                            .textFieldStyle(.plain).padding(14)
                            .background(Color.mileageField, in: RoundedRectangle(cornerRadius: 14))
                            .accessibilityLabel("Search purpose or notes")
                    }
                    MileagePillPicker(options: ["All", "Business", "Personal"], selection: $filter)
                    MileageMonthPicker(selection: $selectedMonth, trips: store.completedTrips)
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(filtered.reduce(0) { $0 + $1.miles }, format: .number.precision(.fractionLength(1)))
                                    .font(.system(size: 38, weight: .semibold)).tracking(-1.2).monospacedDigit()
                                Text("mi").font(.headline.weight(.regular))
                            }
                            Text("\(filtered.count) \(filtered.count == 1 ? "trip" : "trips")")
                                .font(.subheadline).foregroundStyle(Color.mileageSecondary)
                        }
                        Spacer()
                        Button { showsAddTrip = true } label: {
                            Label("Add trip", systemImage: "plus").font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 20).frame(minHeight: 48)
                                .foregroundStyle(Color.mileageOnAccent)
                                .background(Color.mileageGreen, in: Capsule())
                        }
                        .disabled(store.isReadOnly)
                    }
                    if let error = store.storageError { IssueBanner(text: error) }
                    if filter == "Review" {
                        Label("Showing trips that need review", systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(Color.mileageWarning)
                    }
                    if filtered.isEmpty {
                        ContentUnavailableView("No trips in this view", systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                                               description: Text("Choose another month, adjust your search, or add a trip."))
                            .frame(maxWidth: .infinity).padding(.vertical, 32)
                    }
                    ForEach(groupedTrips, id: \.day) { group in
                        VStack(spacing: 0) {
                            HStack {
                                Text(dayTitle(group.day)).font(.headline.weight(.medium))
                                Spacer()
                                Text("\(group.trips.count) \(group.trips.count == 1 ? "trip" : "trips")")
                                    .font(.caption).foregroundStyle(Color.mileageSecondary)
                            }.padding(.bottom, 10)
                            Divider().overlay(Color.mileageSeparator)
                            ForEach(group.trips) { trip in
                                NavigationLink { TripDetailView(tripID: trip.id) } label: { TripRow(trip: trip) }
                                    .buttonStyle(.plain)
                                Divider().overlay(Color.mileageSeparator)
                            }
                        }
                    }
                }
                .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 24)
            }
            .background(Color.mileageBackground)
            .foregroundStyle(Color.mileagePrimary)
            .toolbar(.hidden, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $showsAddTrip) { ManualTripView() }
    }

    private func dayTitle(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.month(.abbreviated).day())
    }
}

struct MileagePillPicker: View {
    var options: [String]
    @Binding var selection: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var labels: [String: String] = [:]

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker("Selection", selection: $selection) {
                ForEach(options, id: \.self) { Text(labels[$0] ?? $0).tag($0) }
            }.pickerStyle(.menu).frame(minHeight: 44)
        } else {
            HStack(spacing: 0) {
                ForEach(options, id: \.self) { option in
                    Button { selection = option } label: {
                        Text(labels[option] ?? option).font(.system(size: 13, weight: selection == option ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .foregroundStyle(selection == option ? Color.mileageOnAccent : Color.mileagePrimary)
                            .background(selection == option ? Color.mileageGreen : Color.clear, in: Capsule())
                    }
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
                }
            }
            .padding(3)
            .background(Color.mileageField, in: Capsule())
            .overlay { Capsule().strokeBorder(Color.mileageSeparator, lineWidth: 1) }
        }
    }
}

struct MileageMonthPicker: View {
    @Binding var selection: Date
    var trips: [Trip]
    var compact = false

    private var months: [Date] {
        let calendar = Calendar.current
        let current = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        let history = trips.compactMap { calendar.date(from: calendar.dateComponents([.year, .month], from: $0.startedAt)) }
        let recent = (0..<12).compactMap { calendar.date(byAdding: .month, value: -$0, to: current) }
        return Array(Set(history + recent + [calendar.date(from: calendar.dateComponents([.year, .month], from: selection)) ?? selection])).sorted(by: >)
    }

    var body: some View {
        Menu {
            ForEach(months, id: \.self) { month in
                Button(month.formatted(.dateTime.month(.wide).year())) { selection = month }
            }
        } label: {
            HStack(spacing: 10) {
                if !compact { Image(systemName: "calendar").foregroundStyle(Color.mileageSecondary) }
                Text(selection, format: .dateTime.month(.wide).year())
                    .font(compact ? .caption : .subheadline)
                if !compact { Spacer() }
                Image(systemName: "chevron.down").font(.caption2).foregroundStyle(Color.mileageSecondary)
            }
            .padding(.horizontal, compact ? 13 : 16).frame(minHeight: compact ? 38 : 48)
            .background(Color.mileageCard.opacity(compact ? 0.4 : 0.6), in: RoundedRectangle(cornerRadius: compact ? 22 : 15))
            .overlay { RoundedRectangle(cornerRadius: compact ? 22 : 15).strokeBorder(Color.mileageSeparator, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Month: \(selection.formatted(.dateTime.month(.wide).year()))")
    }
}

struct MileageRouteSymbol: View {
    var accent = false
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.22, y: size.height * 0.13))
                path.addCurve(to: CGPoint(x: size.width * 0.78, y: size.height * 0.87), control1: CGPoint(x: 0, y: size.height * 0.9), control2: CGPoint(x: size.width * 0.45, y: size.height * 0.5))
            }
            .stroke(accent ? Color.mileageAccentText : Color.mileageSecondary, lineWidth: 1.4)
            Circle().fill(Color.mileageBackground).overlay(Circle().stroke(Color.mileagePrimary, lineWidth: 1.8))
                .frame(width: 7, height: 7).position(x: size.width * 0.22, y: size.height * 0.13)
            Circle().fill(Color.mileageBackground).overlay(Circle().stroke(accent ? Color.mileageAccentText : Color.mileagePrimary, lineWidth: 1.8))
                .frame(width: 7, height: 7).position(x: size.width * 0.78, y: size.height * 0.87)
        }
        .frame(width: 25, height: 32)
        .accessibilityHidden(true)
    }
}

private struct ManualTripView: View {
    @EnvironmentObject private var store: MileageStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("mileageDefaultCategory") private var defaultCategory = "Business"
    @State private var category = TripCategory.business
    @State private var purpose = ""
    @State private var miles = ""
    @State private var reason = ""
    @State private var startedAt = Date().addingTimeInterval(-1800)
    @State private var endedAt = Date()
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    Picker("Category", selection: $category) {
                        ForEach(TripCategory.allCases) { Text($0.rawValue).tag($0) }
                    }
                    TextField("Purpose", text: $purpose)
                    DatePicker("Started", selection: $startedAt, in: ...Date())
                    DatePicker("Ended", selection: $endedAt, in: startedAt...Date())
                }.listRowBackground(Color.mileageCard)
                Section {
                    TextField("Total miles", text: $miles).keyboardType(.decimalPad)
                    TextField("Verified source / reason", text: $reason, axis: .vertical)
                } header: { Text("Verified mileage") } footer: {
                    Text("Manual trips have no GPS route. Enter the complete mileage from an odometer or another verified record.")
                }.listRowBackground(Color.mileageCard)
                if let error { Text(error).foregroundStyle(Color.mileageWarning).listRowBackground(Color.mileageWarningSurface) }
            }
            .scrollContentBackground(.hidden).background(Color.mileageBackground)
            .navigationTitle("Add trip").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = miles.trimmingCharacters(in: .whitespacesAndNewlines)
                        let normalized = trimmed.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
                        guard let value = Double(normalized), value.isFinite, value >= 0, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            error = "Enter valid miles and the source used to verify them."; return
                        }
                        guard endedAt >= startedAt else { error = "The end must be after the start."; return }
                        if store.addManualTrip(category: category, purpose: purpose, startedAt: startedAt, endedAt: endedAt, miles: value, reason: reason) { dismiss() }
                        else { error = store.storageError ?? "This trip could not be saved." }
                    }.disabled(store.isReadOnly)
                }
            }
            .onAppear { category = TripCategory(rawValue: defaultCategory) ?? .business }
        }
    }
}

struct MileageShareSheet: UIViewControllerRepresentable {
    var url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct MileageSharedFile: Identifiable {
    let id = UUID()
    var url: URL
}
