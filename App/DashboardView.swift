import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject private var store: MileageStore
    @EnvironmentObject private var tracker: LocationTracker
    @State private var showStart = false
    @State private var showActiveDrive = false
    @State private var requestedStart: (TripCategory, String)?
    var showTrips: () -> Void = {}
    var showSettings: () -> Void = {}

    private var weekStart: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let offset = (calendar.component(.weekday, from: today) + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: today) ?? today
    }

    private var weekTrips: [Trip] {
        let end = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
        return store.completedTrips.filter { $0.startedAt >= weekStart && $0.startedAt < end }
    }

    private var weeklyMiles: Double { weekTrips.reduce(0) { $0 + $1.miles } }
    private var dailyMiles: [Double] {
        (0..<7).map { day in
            guard let date = Calendar.current.date(byAdding: .day, value: day, to: weekStart) else { return 0 }
            return weekTrips.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: date) }.reduce(0) { $0 + $1.miles }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                if let error = store.storageError {
                    IssueBanner(text: error).padding(.horizontal, 24).padding(.vertical, 8)
                } else if let message = tracker.message, store.activeTrip == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        IssueBanner(text: message)
                        Button("Open iPhone Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                        .font(.subheadline)
                        .frame(minHeight: 44)
                    }
                    .padding(.horizontal, 24)
                }
                InstrumentGauge(value: weeklyMiles, maximum: max(200, ceil(weeklyMiles / 50) * 50),
                                title: "This week", weeklyValues: dailyMiles)
                    .padding(.horizontal, 24)
                    .zIndex(1)
                ZStack(alignment: .bottom) {
                    MileageRouteMap(trip: store.completedTrips.first)
                        .frame(height: 225)
                        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.25), .init(color: .black, location: 0.7), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                    Button {
                        if store.activeTrip != nil { showActiveDrive = true }
                        else { showStart = true }
                    } label: {
                        Label(store.activeTrip == nil ? "Start drive" : "Return to drive", systemImage: "play.fill")
                    }
                    .buttonStyle(MileagePrimaryButtonStyle())
                    .frame(maxWidth: 245)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
                    .disabled(store.isReadOnly)
                }
                .padding(.top, -48)
                recentTrips
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
        }
        .background(Color.mileageBackground)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showStart, onDismiss: beginRequestedDrive) {
            StartDriveSheet { category, purpose in
                requestedStart = (category, purpose)
                showStart = false
            }
        }
        .fullScreenCover(isPresented: $showActiveDrive) { ActiveDriveView() }
        .onChange(of: store.activeTrip?.id) { _, id in
            if id != nil { showActiveDrive = true }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Mileage").font(.largeTitle.weight(.semibold)).tracking(-1)
            Spacer(minLength: 0)
            Button(action: showSettings) {
                Image(systemName: "gearshape")
                    .font(.subheadline)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Color.mileageSecondary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
            HStack(spacing: 6) {
                Circle().fill(Color.mileageGreen).frame(width: 7, height: 7)
                Text("Manual tracking").font(.caption2)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(Color.mileageCard.opacity(0.7), in: Capsule())
            .overlay { Capsule().strokeBorder(Color.mileageSeparator, lineWidth: 0.7) }
        }
    }

    private var recentTrips: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recent trips").font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: showTrips) {
                    HStack(spacing: 5) {
                        Text("See all")
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                    .font(.caption)
                    .foregroundStyle(Color.mileageSecondary)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            Divider().overlay(Color.mileageSeparator)
            if store.completedTrips.isEmpty {
                VStack(spacing: 5) {
                    Text("No trips yet").font(.subheadline.weight(.medium))
                    Text("Start a drive to record your first route.")
                        .font(.caption)
                        .foregroundStyle(Color.mileageSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(store.completedTrips.prefix(2)) { trip in
                    NavigationLink { TripDetailView(tripID: trip.id) } label: { TripRow(trip: trip) }
                        .buttonStyle(.plain)
                    Divider().overlay(Color.mileageSeparator)
                }
            }
        }
    }

    private func beginRequestedDrive() {
        guard let request = requestedStart else { return }
        requestedStart = nil
        tracker.start(category: request.0, purpose: request.1)
    }
}

private struct StartDriveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("mileageDefaultCategory") private var defaultCategory = TripCategory.business.rawValue
    @State private var didInitializeCategory = false
    @State private var category: TripCategory = .business
    @State private var purpose = ""
    var onStart: (TripCategory, String) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("Start while parked. Mileage records your route until you pause or end the drive.")
                    .font(.subheadline)
                    .foregroundStyle(Color.mileageSecondary)
                MileageCategoryPicker(selection: $category)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Purpose or destination").font(.caption).foregroundStyle(Color.mileageSecondary)
                    TextField("Optional", text: $purpose)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .padding(16)
                        .background(Color.mileageField, in: RoundedRectangle(cornerRadius: 14))
                        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mileageSeparator, lineWidth: 0.7) }
                }
                Button { onStart(category, purpose.trimmingCharacters(in: .whitespacesAndNewlines)) } label: {
                    Label("Start drive", systemImage: "play.fill")
                }
                .buttonStyle(MileagePrimaryButtonStyle())
                Text("Allow Precise Location when prompted. Recording uses battery; automatic drive detection is not enabled.")
                    .font(.caption)
                    .foregroundStyle(Color.mileageSecondary)
                Spacer(minLength: 0)
            }
            .padding(24)
            .background(Color.mileageBackground)
            .navigationTitle("New drive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .onAppear {
            guard !didInitializeCategory else { return }
            didInitializeCategory = true
            category = TripCategory(rawValue: defaultCategory) ?? .business
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct TripRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            MileageRouteGlyph(highlighted: trip.category == .business)
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.purpose.isEmpty ? "\(trip.category.rawValue) drive" : trip.purpose)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.mileagePrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(trip.startedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(Color.mileageSecondary)
                    if trip.needsReview {
                        Text("Needs review").font(.caption2).foregroundStyle(Color.mileageWarning)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    Text("\(trip.miles.formatted(.number.precision(.fractionLength(1)))) mi")
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.mileagePrimary)
                    Text(trip.category.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(trip.category == .business ? Color.mileageAccentText : Color.mileageSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(trip.category == .business ? Color.mileageGreen.opacity(0.12) : Color.mileageField, in: Capsule())
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Color.mileageSecondary)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
