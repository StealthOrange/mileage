import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject private var store: MileageStore
    @EnvironmentObject private var tracker: LocationTracker
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var mileageSize: CGFloat = MileageTokens.Typography.metric
    @ScaledMetric(relativeTo: .title) private var summarySize: CGFloat = MileageTokens.Typography.title
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
                VStack(alignment: .leading, spacing: MileageTokens.Space.xl) {
                    header
                    if let error = store.storageError { IssueBanner(text: error) }
                    if let message = tracker.message {
                        VStack(alignment: .leading, spacing: MileageTokens.Space.sm) {
                            IssueBanner(text: message)
                            Button("Open iPhone Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }
                            .buttonStyle(MileageSecondaryButtonStyle())
                        }
                    }
                    if let active = store.activeTrip { activeCard(active) }
                    else { startCard }
                    monthSummary
                    recentTrips
                    Label("Saved on your iPhone. Only shared when you export.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(Color.mileageSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MileageTokens.Space.sm)
                }
                .padding(MileageTokens.Space.xl)
            }
            .background(Color.mileageBackground)
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .confirmationDialog("Finish this trip?", isPresented: $confirmStop, titleVisibility: .visible) {
                Button("Stop and save trip") { tracker.stop() }
                Button("Keep recording", role: .cancel) {}
            } message: { Text("Stop only after you have parked.") }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: MileageTokens.Space.lg) {
            VStack(alignment: .leading, spacing: MileageTokens.Space.xs) {
                Text("Mileage").font(.largeTitle.weight(.semibold)).tracking(-1)
                Text("Your miles, in one place.")
                    .font(.subheadline)
                    .foregroundStyle(Color.mileageSecondary)
            }
            Spacer(minLength: 0)
            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.body.weight(.medium))
                    .frame(width: 48, height: 48)
                    .foregroundStyle(Color.mileagePrimary)
                    .background(Color.mileageCard, in: Circle())
                    .overlay { Circle().strokeBorder(Color.mileageSeparator, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings and export")
        }
    }

    private var startCard: some View {
        MileageCard {
            Label("Ready to record", systemImage: "location.north.circle")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.mileageGreen)
            VStack(alignment: .leading, spacing: MileageTokens.Space.sm) {
                Text("Start your next trip")
                    .font(.title2.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Start while parked. Your route and miles are recorded as you drive.")
                    .font(.subheadline)
                    .foregroundStyle(Color.mileageSecondary)
            }
            Picker("Trip type", selection: $category) {
                ForEach(TripCategory.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            VStack(alignment: .leading, spacing: MileageTokens.Space.sm) {
                Text("Purpose or destination")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.mileageSecondary)
                TextField("Optional", text: $purpose)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .padding(MileageTokens.Space.md)
                    .frame(minHeight: 48)
                    .background(Color.mileageField, in: RoundedRectangle(cornerRadius: MileageTokens.Radius.control))
                    .overlay {
                        RoundedRectangle(cornerRadius: MileageTokens.Radius.control)
                            .strokeBorder(Color.mileageSeparator, lineWidth: 1)
                    }
                    .accessibilityLabel("Purpose or destination, optional")
            }
            Button { tracker.start(category: category, purpose: purpose); purpose = "" } label: {
                Label("Start trip", systemImage: "play.fill")
            }
            .buttonStyle(MileagePrimaryButtonStyle())
            .disabled(store.isReadOnly)
            Text("Start and stop manually. Recording can continue with your screen locked or while using Maps.")
                .font(.caption)
                .foregroundStyle(Color.mileageSecondary)
        }
    }

    private func activeCard(_ trip: Trip) -> some View {
        MileageCard {
            ViewThatFits(in: .horizontal) {
                HStack {
                    recordingStatus
                    Spacer()
                    Text(trip.category.rawValue).font(.caption).foregroundStyle(Color.mileageSecondary)
                }
                VStack(alignment: .leading, spacing: MileageTokens.Space.sm) {
                    recordingStatus
                    Text(trip.category.rawValue).font(.caption).foregroundStyle(Color.mileageSecondary)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: MileageTokens.Space.sm) {
                    mileageNumber(trip)
                    Text("mi").font(.title3).foregroundStyle(Color.mileageSecondary)
                }
                VStack(alignment: .leading, spacing: MileageTokens.Space.xs) {
                    mileageNumber(trip)
                    Text("miles").font(.subheadline).foregroundStyle(Color.mileageSecondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(trip.miles.formatted(.number.precision(.fractionLength(2)))) miles recorded")
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: MileageTokens.Space.sm) {
                    Text("Started \(trip.startedAt.formatted(date: .omitted, time: .shortened)) · \(duration(trip, now: context.date)) elapsed")
                        .monospacedDigit()
                        .foregroundStyle(Color.mileageSecondary)
                    if tracker.isRecording {
                        let stale = tracker.lastFixAt.map { context.date.timeIntervalSince($0) > 45 } ?? true
                        Label(stale ? "Waiting for a fresh GPS fix" : "GPS signal received",
                              systemImage: stale ? "antenna.radiowaves.left.and.right.slash" : "location.fill")
                            .foregroundStyle(stale ? Color.mileageWarning : Color.mileageGreen)
                    } else {
                        Text("Resume when ready. Missing sections will need review.")
                            .foregroundStyle(Color.mileageWarning)
                    }
                }
                .font(.caption)
            }
            if !trip.purpose.isEmpty { Text(trip.purpose).font(.headline) }
            if !tracker.isRecording {
                Button { tracker.resume() } label: {
                    Label("Resume trip", systemImage: "play.fill")
                }
                .buttonStyle(MileagePrimaryButtonStyle())
                .disabled(store.isReadOnly)
            }
            Button { confirmStop = true } label: {
                Label("Stop and save", systemImage: "stop.fill")
            }
            .buttonStyle(MileageSecondaryButtonStyle())
            .disabled(store.isReadOnly)
            Text("Keep Mileage running in the background. Force-quitting or restarting your phone can interrupt recording.")
                .font(.caption)
                .foregroundStyle(Color.mileageSecondary)
        }
    }

    private var recordingStatus: some View {
        Label(tracker.isRecording ? "Recording trip" : "Recording interrupted",
              systemImage: tracker.isRecording ? "record.circle" : "pause.circle")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(tracker.isRecording ? Color.mileageGreen : Color.mileageWarning)
    }

    private func mileageNumber(_ trip: Trip) -> some View {
        Text(trip.miles, format: .number.precision(.fractionLength(2)))
            .font(.system(size: mileageSize, weight: .medium))
            .tracking(-2)
            .monospacedDigit()
            .minimumScaleFactor(0.6)
            .lineLimit(1)
    }

    private var monthSummary: some View {
        MileageCard {
            HStack {
                Text(Date(), format: .dateTime.month(.wide).year())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.mileageSecondary)
                Spacer()
                Image(systemName: "chart.bar.xaxis").foregroundStyle(Color.mileageSecondary)
                    .accessibilityHidden(true)
            }
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: MileageTokens.Space.xl)) : AnyLayout(HStackLayout(alignment: .top, spacing: MileageTokens.Space.xl))
            layout {
                metric(value: monthTrips.filter { $0.category == .business }.reduce(0) { $0 + $1.miles }.formatted(.number.precision(.fractionLength(1))), label: "Business miles")
                metric(value: "\(monthTrips.count)", label: "Completed trips")
            }
            if monthTrips.contains(where: \.needsReview) {
                Label("Includes trips that need review", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(Color.mileageWarning)
            }
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: MileageTokens.Space.xs) {
            Text(value)
                .font(.system(size: summarySize, weight: .medium))
                .tracking(-1)
                .monospacedDigit()
            Text(label).font(.caption).foregroundStyle(Color.mileageSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var recentTrips: some View {
        VStack(alignment: .leading, spacing: MileageTokens.Space.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent trips").font(.headline)
                Spacer()
                NavigationLink("View all") { TripHistoryView() }
                    .font(.subheadline.weight(.medium))
                    .frame(minHeight: 44)
            }
            if store.completedTrips.isEmpty {
                ContentUnavailableView("Your first trip starts here", systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                                       description: Text("Completed trips will appear here, with their route and mileage."))
                    .padding(.vertical, MileageTokens.Space.sm)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.completedTrips.prefix(5).enumerated()), id: \.element.id) { index, trip in
                        if index > 0 { Divider().overlay(Color.mileageSeparator).padding(.leading, 64) }
                        NavigationLink { TripDetailView(tripID: trip.id) } label: { TripRow(trip: trip) }
                            .buttonStyle(.plain)
                    }
                }
                .background(Color.mileageCard, in: RoundedRectangle(cornerRadius: MileageTokens.Radius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: MileageTokens.Radius.card)
                        .strokeBorder(Color.mileageSeparator, lineWidth: 1)
                }
            }
        }
    }

    private func duration(_ trip: Trip, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(trip.startedAt)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }
}

struct TripRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var trip: Trip

    var body: some View {
        HStack(alignment: .center, spacing: MileageTokens.Space.md) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: trip.category == .business ? "briefcase" : "car")
                    .font(.body)
                    .foregroundStyle(Color.mileageSecondary)
                    .frame(width: 36, height: 40)
                    .accessibilityHidden(true)
            }
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: MileageTokens.Space.sm)) : AnyLayout(HStackLayout(alignment: .center, spacing: MileageTokens.Space.md))
            layout {
                VStack(alignment: .leading, spacing: MileageTokens.Space.xs) {
                    Text(trip.purpose.isEmpty ? "\(trip.category.rawValue) trip" : trip.purpose)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.mileagePrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(trip.startedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(Color.mileageSecondary)
                    if trip.needsReview {
                        Label("Needs review", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(Color.mileageWarning)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                    Text(trip.miles, format: .number.precision(.fractionLength(2)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.mileagePrimary)
                        .monospacedDigit()
                    Text("miles").font(.caption2).foregroundStyle(Color.mileageSecondary)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.mileageSecondary)
                .accessibilityHidden(true)
        }
        .padding(MileageTokens.Space.lg)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
