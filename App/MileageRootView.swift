import SwiftUI

struct MileageRootView: View {
    private enum Tab: CaseIterable {
        case home, trips, reports, settings

        var title: String {
            switch self {
            case .home: return "Home"
            case .trips: return "Trips"
            case .reports: return "Reports"
            case .settings: return "Settings"
            }
        }

        var symbol: String {
            switch self {
            case .home: return "house"
            case .trips: return "list.bullet"
            case .reports: return "chart.bar"
            case .settings: return "gearshape"
            }
        }
    }

    @State private var selectedTab = Tab.home

    var body: some View {
        Group {
            switch selectedTab {
            case .home:
                NavigationStack {
                    DashboardView(showTrips: { selectedTab = .trips }, showSettings: { selectedTab = .settings })
                }
            case .trips:
                TripHistoryView()
            case .reports:
                ReportsView()
            case .settings:
                SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomNavigation }
        .background(Color.mileageBackground)
        .tint(.mileageAccentText)
    }

    private var bottomNavigation: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.mileageSeparator).frame(height: 0.5)
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    let isSelected = selectedTab == tab
                    Button { selectedTab = tab } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tab == .home && isSelected ? "house.fill" : tab.symbol)
                                .font(.system(size: 21, weight: .regular))
                                .frame(height: 24)
                            Text(tab.title)
                                .font(.caption2)
                        }
                        .foregroundStyle(isSelected ? Color.mileageAccentText : Color.mileageSecondary)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 5)
            .padding(.bottom, 2)
        }
        .background(Color.mileageBackground.ignoresSafeArea(edges: .bottom))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }
}
