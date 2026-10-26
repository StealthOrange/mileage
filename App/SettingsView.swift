import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: MileageStore
    @EnvironmentObject private var tracker: LocationTracker
    @Environment(\.dismiss) private var dismiss
    @State private var share: ShareFile?
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Your records") {
                    Button { prepareExport(backup: false) } label: { Label("Export completed trips as CSV", systemImage: "square.and.arrow.up") }
                        .disabled(store.completedTrips.isEmpty || store.isReadOnly)
                    Button { prepareExport(backup: true) } label: { Label("Export full backup (includes routes)", systemImage: "externaldrive") }
                    Text("Export a backup regularly. Trips are stored on this phone; deleting Mileage deletes its local records. Backup restore is not included in this version.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let exportError { Text(exportError).foregroundStyle(.orange) }
                }
                Section("Location access") {
                    LabeledContent("Permission", value: permissionText)
                    LabeledContent("Precise Location", value: tracker.hasPreciseLocation ? "On" : "Off")
                    Button("Open iPhone Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    Text("Start a trip while Mileage is open. With location access and Precise Location enabled, that trip can continue with the screen locked or while using Maps. iOS shows a location indicator.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Recording limits") {
                    Text("Start and stop each trip yourself, while parked. Automatic drive detection is not included.")
                    Text("Force-quitting, restarting your phone, disabling location access, GPS loss, or a storage error can interrupt recording. Reopen Mileage to resume an interrupted trip.")
                    Text("GPS mileage is approximate. Missing sections are excluded and flagged for review. Use a verified correction when needed.")
                    Text("Recording uses battery. A charger is useful on longer drives.")
                }
                Section("Privacy") {
                    Text("No Mileage account, ads, analytics, or cloud backend. Trip records stay on this device unless you export them. Maps use Apple MapKit. Device backups follow your iPhone backup settings.")
                }
                Section { LabeledContent("Version", value: "0.1.0 · Personal beta") }
            }
            .navigationTitle("Settings & export").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $share) { ShareSheet(url: $0.url) }
        }
    }

    private var permissionText: String {
        switch tracker.authorization {
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "While Using"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not requested"
        @unknown default: return "Unknown"
        }
    }

    private func prepareExport(backup: Bool) {
        do {
            let url = try (backup ? store.backupURL() : store.csvURL())
            share = ShareFile(url: url)
            exportError = nil
        } catch { exportError = "Could not create the export: \(error.localizedDescription)" }
    }
}

private struct ShareFile: Identifiable {
    let id = UUID()
    var url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    var url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
