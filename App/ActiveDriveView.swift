import SwiftUI

struct ActiveDriveView: View {
    @EnvironmentObject private var store: MileageStore
    @EnvironmentObject private var tracker: LocationTracker
    @Environment(\.dismiss) private var dismiss
    @State private var confirmStop = false

    var body: some View {
        ZStack {
            Color.mileageBackground.ignoresSafeArea()
            if let trip = store.activeTrip {
                ScrollView {
                    VStack(spacing: 0) {
                        header
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                            .padding(.bottom, 8)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            InstrumentGauge(value: trip.miles, maximum: max(20, ceil(trip.miles / 10) * 10),
                                            title: "Distance", detail: elapsed(trip, at: context.date))
                        }
                        .padding(.horizontal, 24)
                        .overlay(alignment: .bottom) {
                            Text(tracker.isRecording ? "GPS recording active" : (tracker.isPaused ? "GPS paused · resume when ready" : "Recording interrupted · resume when ready"))
                                .font(.caption)
                                .foregroundStyle(Color.mileageSecondary)
                                .padding(.bottom, 10)
                        }
                        MileageRouteMap(trip: trip)
                            .frame(height: 280)
                            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.2), .init(color: .black, location: 0.75), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                            .padding(.top, -32)
                        if let error = store.storageError {
                            IssueBanner(text: error).padding(.horizontal, 24)
                        } else if let message = tracker.message {
                            IssueBanner(text: message).padding(.horizontal, 24)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    controls(trip)
                }
            }
        }
        .foregroundStyle(Color.mileagePrimary)
        .interactiveDismissDisabled()
        .confirmationDialog("End this drive?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("End drive and save") { tracker.stop() }
            Button(tracker.isRecording ? "Keep recording" : "Keep drive open", role: .cancel) {}
        } message: { Text("End your drive only after you have parked. Your recorded route will be saved.") }
        .onChange(of: store.activeTrip?.id) { _, id in if id == nil { dismiss() } }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.title3)
                    .frame(width: 44, height: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Return to dashboard. Drive remains open.")
            Text("Drive in progress")
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Image(systemName: "location").font(.caption)
                Circle().fill(tracker.isRecording ? Color.mileageGreen : Color.mileageWarning).frame(width: 7, height: 7)
                Text(tracker.isRecording ? "Recording" : (tracker.isPaused ? "Paused" : "Interrupted")).font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.mileageCard.opacity(0.6), in: Capsule())
            .overlay { Capsule().strokeBorder(Color.mileageSeparator, lineWidth: 0.7) }
        }
    }

    private func controls(_ trip: Trip) -> some View {
        VStack(spacing: 14) {
            MileageCategoryPicker(selection: Binding(get: { store.activeTrip?.category ?? trip.category },
                                                     set: { store.setActiveCategory($0) }))
                .padding(.horizontal, 32)
                .disabled(store.isReadOnly)
            HStack(spacing: 10) {
                Button {
                    if tracker.isRecording { tracker.pause() }
                    else { tracker.resume() }
                } label: {
                    Label(tracker.isRecording ? "Pause" : "Resume", systemImage: tracker.isRecording ? "pause.fill" : "play.fill")
                }
                .buttonStyle(MileageSecondaryButtonStyle())
                .disabled(store.isReadOnly)
                Button { confirmStop = true } label: {
                    Label("End drive", systemImage: "stop.fill")
                }
                .buttonStyle(MileagePrimaryButtonStyle())
                .disabled(store.isReadOnly)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(LinearGradient(colors: [Color.mileageBackground.opacity(0), Color.mileageBackground, Color.mileageBackground], startPoint: .top, endPoint: .bottom))
    }

    private func elapsed(_ trip: Trip, at date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(trip.startedAt)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }
}
