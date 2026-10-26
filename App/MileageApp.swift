import SwiftUI

@main
struct MileageApp: App {
    @StateObject private var store: MileageStore
    @StateObject private var tracker: LocationTracker
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = MileageStore()
        _store = StateObject(wrappedValue: store)
        _tracker = StateObject(wrappedValue: LocationTracker(store: store))
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(store)
                .environmentObject(tracker)
                .tint(.mileageGreen)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { tracker.refreshStatus() }
                }
        }
    }
}
