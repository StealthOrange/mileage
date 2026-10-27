import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: MileageStore
    @EnvironmentObject private var tracker: LocationTracker
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("mileageAppearance") private var appearance = MileageAppearance.system.rawValue
    @AppStorage("mileageDisplayName") private var displayName = "Your profile"
    @AppStorage("mileageVehicleName") private var vehicleName = "My vehicle"
    @AppStorage("mileageDefaultCategory") private var defaultCategory = "Business"
    @AppStorage("mileageUnit") private var unit = "Miles"
    @AppStorage("mileageLastBackupDate") private var lastBackupDate = 0.0
    @State private var editor: SettingsEditor?
    @State private var showsExports = false
    @State private var showsBackupInfo = false
    @State private var sharedFile: MileageSharedFile?
    @State private var exportError: String?
    var showsDone = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Settings").font(.system(.largeTitle, weight: .bold))
                        Spacer()
                        if showsDone { Button("Done") { dismiss() }.frame(minHeight: 44) }
                    }
                    Button { editor = .profile } label: {
                        HStack(spacing: 14) {
                            Text(initials).font(.title3.weight(.medium)).frame(width: 58, height: 58)
                                .background(Color.mileageField, in: Circle())
                                .overlay { Circle().strokeBorder(Color.mileageSeparator, lineWidth: 1) }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(displayName.isEmpty ? "Your profile" : displayName).font(.headline)
                                Text("On-device profile").font(.caption).foregroundStyle(Color.mileageSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.mileageSecondary)
                        }.padding(.vertical, 2)
                    }.buttonStyle(.plain)
                    settingsGroup("Tracking") {
                        unavailableTracking("Automatic tracking", icon: "scope", subtitle: "Not available · start trips manually")
                        rowDivider
                        settingsRow("Location access", icon: "mappin.and.ellipse", subtitle: permissionText) { openPhoneSettings() }
                        rowDivider
                        unavailableTracking("Motion detection", icon: "sensor.tag.radiowaves.forward", subtitle: "Not available in this version")
                    }
                    settingsGroup("Preferences") {
                        HStack(spacing: 14) {
                            Image(systemName: "ruler").font(.title3).frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Units").font(.subheadline)
                                Text("Miles").font(.caption).foregroundStyle(Color.mileageSecondary)
                            }
                            Spacer()
                        }.padding(.horizontal, 16).frame(minHeight: 58)
                        rowDivider
                        Menu {
                            ForEach(TripCategory.allCases) { category in
                                Button(category.rawValue) { defaultCategory = category.rawValue }
                            }
                        } label: {
                            rowContent("Default trip type", icon: "briefcase", subtitle: defaultCategory)
                        }.buttonStyle(.plain)
                        rowDivider
                        appearanceRow
                    }
                    settingsGroup("Data") {
                        settingsRow("Export data", icon: "square.and.arrow.up") { showsExports = true }
                        rowDivider
                        settingsRow("Backup status", icon: "externaldrive", subtitle: lastBackupDate > 0 ? "Last exported \(Date(timeIntervalSince1970: lastBackupDate).formatted(.dateTime.month(.abbreviated).day()))" : "Stored locally · no backup exported") { showsBackupInfo = true }
                    }
                    settingsGroup(nil) {
                        settingsRow("Manage vehicle", icon: "car", subtitle: vehicleName.isEmpty ? "Add your vehicle" : vehicleName) { editor = .vehicle }
                    }
                    if let error = store.storageError { IssueBanner(text: error) }
                    if let exportError { IssueBanner(text: exportError) }
                    Text("Mileage 0.1.0 · Personal beta\nYour records stay on this iPhone unless you export them.")
                        .font(.caption2).foregroundStyle(Color.mileageSecondary).frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.vertical, 4)
                }.padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 22)
            }
            .background(Color.mileageBackground).foregroundStyle(Color.mileagePrimary)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editor) { field in
                switch field {
                case .profile: TripTextEditor(title: "Your profile", text: $displayName, multiline: false, explanation: "A display name stored on this iPhone. No account is created.")
                case .vehicle: TripTextEditor(title: "Manage vehicle", text: $vehicleName, multiline: false, explanation: "Your default vehicle name for Mileage.")
                }
            }
            .sheet(item: $sharedFile) { MileageShareSheet(url: $0.url) }
            .confirmationDialog("Export your records", isPresented: $showsExports, titleVisibility: .visible) {
                Button("Completed trips as CSV") { prepareExport(backup: false) }.disabled(store.completedTrips.isEmpty || store.isReadOnly)
                Button("Full backup with routes (JSON)") { prepareExport(backup: true) }
                Button("Cancel", role: .cancel) {}
            } message: { Text("CSV includes completed trips. The full backup includes all recorded route points and any active trip.") }
            .alert("Local backup", isPresented: $showsBackupInfo) {
                Button("Export full backup") { prepareExport(backup: true) }
                Button("Done", role: .cancel) {}
            } message: {
                Text("Trip records are stored on this iPhone. Export a backup regularly; deleting the app deletes its local records. An export date confirms a file was prepared, not that it was saved elsewhere. Backup import is not available yet.")
            }
        }
        .preferredColorScheme(MileageAppearance(rawValue: appearance)?.colorScheme)
    }

    private var initials: String {
        guard !displayName.isEmpty, displayName != "Your profile" else { return "M" }
        return displayName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    private var permissionText: String {
        let permission: String
        switch tracker.authorization {
        case .authorizedAlways: permission = "Always"
        case .authorizedWhenInUse: permission = "While using"
        case .denied: permission = "Denied"
        case .restricted: permission = "Restricted"
        case .notDetermined: permission = "Not requested"
        @unknown default: permission = "Unknown"
        }
        return permission + (tracker.hasPreciseLocation ? " · Precise on" : " · Precise off")
    }

    private var rowDivider: some View { Divider().overlay(Color.mileageSeparator) }

    private var appearanceRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            Label("Appearance", systemImage: "sun.max").font(.subheadline)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            MileagePillPicker(options: ["system", "light", "dark"], selection: $appearance, labels: ["system": "System", "light": "Light", "dark": "Dark"])
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 205)
        }.padding(.horizontal, 16).padding(.vertical, 8).frame(minHeight: 58)
    }

    private func settingsGroup<Content: View>(_ title: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { Text(title).font(.subheadline).foregroundStyle(Color.mileagePrimary) }
            VStack(spacing: 0, content: content)
                .background(Color.mileageCard.opacity(0.7), in: RoundedRectangle(cornerRadius: 15))
                .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(Color.mileageSeparator, lineWidth: 1) }
        }
    }

    private func rowContent(_ title: String, icon: String, subtitle: String? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title3).frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(Color.mileageSecondary).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.mileageSecondary)
        }.padding(.horizontal, 16).padding(.vertical, 12).frame(minHeight: 54)
    }

    private func settingsRow(_ title: String, icon: String, subtitle: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) { rowContent(title, icon: icon, subtitle: subtitle) }.buttonStyle(.plain)
    }

    private func unavailableTracking(_ title: String, icon: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title3).frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline)
                Text(subtitle).font(.caption).foregroundStyle(Color.mileageSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Toggle(title, isOn: .constant(false)).labelsHidden().disabled(true).scaleEffect(0.85, anchor: .trailing)
                .accessibilityLabel("\(title), not available")
        }.padding(.horizontal, 16).padding(.vertical, 10).frame(minHeight: 58)
    }

    private func openPhoneSettings() { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }

    private func prepareExport(backup: Bool) {
        do {
            let url = try (backup ? store.backupURL() : store.csvURL())
            sharedFile = MileageSharedFile(url: url)
            if backup { lastBackupDate = Date().timeIntervalSince1970 }
            exportError = nil
        } catch { exportError = "Could not create the export: \(error.localizedDescription)" }
    }
}

private enum SettingsEditor: String, Identifiable {
    case profile, vehicle
    var id: String { rawValue }
}
