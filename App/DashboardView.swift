import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject private var store: MileageStore
    @EnvironmentObject private var tracker: LocationTracker
    @State private var category: TripCategory = .business
    @State private var purpose = ""
    @State private var showSettings = false
    @State private var confirmStop = false

    private var monthTrips: [Trip] {
        store.completedTrips.filter {
            Calendar.current.isDate($0.startedAt, equalTo: Date(), toGranularity: .month)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let error = store.storageError { IssueBanner(text: error) }
                    if let message = tracker.message {
                        VStack(alignment: .leading, spacing: 8) {
                            IssueBanner(text: message)
                            Button("Open iPhone Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                    }
                    if let active = store.activeTrip { activeCard(active) }
                    else { startCard }
                    monthSummary
                    HStack {
                        Text("Recent trips").font(.title2.bold())
                        Spacer()
                        NavigationLink("View all") { TripHistoryView() }.font(.subheadline.weight(.semibold))
                    }
                    if store.completedTrips.isEmpty {
                        ContentUnavailableView("Your first mile starts here", systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                                               description: Text("Start a trip before you drive. Your route and miles will appear here."))
                            .padding(.vertical, 8)
                    } else {
                        ForEach(store.completedTrips.prefix(5)) { trip in
                            NavigationLink { TripDetailView(tripID: trip.id) } label: { TripRow(trip: trip) }
                                .buttonStyle(.plain)
                        }
                    }
                    Label("Saved on your iPhone. No account required.", systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical)
                }
                .padding(22)
            }
            .background(Color.mileageBackground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .confirmationDialog("Finish this trip?", isPresented: $confirmStop, titleVisibility: .visible) {
                Button("Stop and save trip") { tracker.stop() }
                Button("Keep recording", role: .cancel) {}
            } message: { Text("Stop only after you have parked.") }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("YOUR MILES, ACCOUNTED FOR.").font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(Color.mileageGreen)
                Text("Mileage").font(.system(size: 38, weight: .bold, design: .rounded))
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3").font(.title3).padding(14)
                    .background(Color.mileageCard, in: Circle())
            }
            .accessibilityLabel("Settings and export")
        }
    }

    private var startCard: some View {
        MileageCard {
            HStack {
                Image(systemName: "location.north.circle.fill").foregroundStyle(Color.mileageGreen).font(.title)
                Spacer()
                Text("READY WHEN YOU ARE").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
            }
            Text("Make every\nmile count.").font(.system(size: 34, weight: .semibold, design: .rounded))
            Text("Tap Start before driving. Keep recording with your screen locked or while using Maps.")
                .font(.subheadline).foregroundStyle(.secondary)
            Picker("Trip type", selection: $category) {
                ForEach(TripCategory.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            TextField("Purpose or destination (optional)", text: $purpose)
                .textFieldStyle(.roundedBorder).textInputAutocapitalization(.sentences)
            Button { tracker.start(category: category, purpose: purpose); purpose = "" } label: {
                Label("Start trip", systemImage: "play.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent).foregroundStyle(.black).disabled(store.isReadOnly)
            Text("GPS recording uses battery. No automatic drive detection in this version.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func activeCard(_ trip: Trip) -> some View {
        MileageCard {
            HStack {
                Label(tracker.isRecording ? "Recording trip" : "Recording interrupted",
                      systemImage: tracker.isRecording ? "record.circle" : "pause.circle")
                    .foregroundStyle(tracker.isRecording ? Color.mileageGreen : Color.orange)
                Spacer()
                Text(trip.category.rawValue).font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(trip.miles, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 64, weight: .semibold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.5)
                Text("mi").font(.title2).foregroundStyle(.secondary)
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Started \(trip.startedAt.formatted(date: .omitted, time: .shortened)) · \(duration(trip, now: context.date)) elapsed")
                    if tracker.isRecording {
                        let stale = tracker.lastFixAt.map { context.date.timeIntervalSince($0) > 45 } ?? true
                        Label(stale ? "Waiting for a fresh GPS fix" : "GPS signal received",
                              systemImage: stale ? "antenna.radiowaves.left.and.right.slash" : "location.fill")
                            .foregroundStyle(stale ? Color.orange : Color.mileageGreen)
                    } else {
                        Text("Resume to continue. Any missing route needs review.").foregroundStyle(.orange)
                    }
                }.font(.caption).foregroundStyle(.secondary)
            }
            if !trip.purpose.isEmpty { Text(trip.purpose).font(.headline) }
            if !tracker.isRecording {
                Button { tracker.resume() } label: {
                    Label("Resume trip", systemImage: "play.fill").frame(maxWidth: .infinity).padding(10)
                }.buttonStyle(.borderedProminent).foregroundStyle(.black).disabled(store.isReadOnly)
            }
            Button { confirmStop = true } label: {
                Label("Stop and save", systemImage: "stop.fill").frame(maxWidth: .infinity).padding(10)
            }.buttonStyle(.bordered).tint(.orange).disabled(store.isReadOnly)
            Text("Let Mileage run in the background. Swiping it away or restarting the phone can interrupt recording.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var monthSummary: some View {
        MileageCard {
            HStack {
                Text(Date(), format: .dateTime.month(.wide).year()).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chart.bar.xaxis").foregroundStyle(Color.mileageGreen)
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(monthTrips.filter { $0.category == .business }.reduce(0) { $0 + $1.miles },
                         format: .number.precision(.fractionLength(1)))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                    Text("Business miles").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(monthTrips.count)").font(.system(size: 32, weight: .semibold, design: .rounded))
                    Text("Completed trips").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if monthTrips.contains(where: \.needsReview) {
                Label("Includes trips that need review", systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private func duration(_ trip: Trip, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(trip.startedAt)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }
}

struct TripRow: View {
    var trip: Trip
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: trip.category == .business ? "briefcase.fill" : "car.fill")
                .foregroundStyle(Color.mileageGreen).frame(width: 42, height: 42)
                .background(Color.mileageGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 5) {
                Text(trip.purpose.isEmpty ? "\(trip.category.rawValue) trip" : trip.purpose).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(trip.startedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
                if trip.needsReview { Text("Needs review").font(.caption2).foregroundStyle(.orange) }
            }
            Spacer(minLength: 5)
            VStack(alignment: .trailing, spacing: 4) {
                Text(trip.miles, format: .number.precision(.fractionLength(2))).font(.headline).monospacedDigit()
                Text("miles").font(.caption2).foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(16).background(Color.mileageCard, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}
