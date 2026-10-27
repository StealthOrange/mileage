import SwiftUI

@main
struct MileageApp: App {
    @StateObject private var store: MileageStore
    @StateObject private var tracker: LocationTracker
    @AppStorage("mileageAppearance") private var appearance = MileageAppearance.system.rawValue
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = MileageStore()
        _store = StateObject(wrappedValue: store)
        _tracker = StateObject(wrappedValue: LocationTracker(store: store))
    }

    var body: some Scene {
        WindowGroup {
            MileageRootView()
                .environmentObject(store)
                .environmentObject(tracker)
                .tint(.mileageAccentText)
                .foregroundStyle(Color.mileagePrimary)
                .preferredColorScheme((MileageAppearance(rawValue: appearance) ?? .system).colorScheme)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { tracker.becameActive() }
                }
        }
    }
}
