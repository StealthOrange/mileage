import SwiftUI

struct TripHistoryView: View {
    @EnvironmentObject private var store: MileageStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var filter = "All"
    @State private var query = ""

    private var filtered: [Trip] {
        store.completedTrips.filter {
            (filter == "All" || $0.category.rawValue == filter || (filter == "Review" && $0.needsReview)) &&
            (query.isEmpty || "\($0.purpose) \($0.notes)".localizedCaseInsensitiveContains(query))
        }
    }

    private var filterPicker: some View {
        Picker("Filter trips", selection: $filter) {
            ForEach(["All", "Business", "Personal", "Review"], id: \.self) { Text($0).tag($0) }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MileageTokens.Space.lg) {
                Text("Your trips, all in one place.")
                    .font(.subheadline)
                    .foregroundStyle(Color.mileageSecondary)
                if dynamicTypeSize.isAccessibilitySize {
                    filterPicker.pickerStyle(.menu).frame(minHeight: 44)
                } else {
                    filterPicker.pickerStyle(.segmented)
                }
                if filtered.isEmpty {
                    ContentUnavailableView(
                        store.completedTrips.isEmpty ? "No trips yet" : "No matching trips",
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                        description: Text(store.completedTrips.isEmpty
                                          ? "Start a trip from Mileage. Your completed trips will be saved here."
                                          : "Try another filter or search for a different purpose or note.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MileageTokens.Space.xl)
                } else {
                    Text("\(filtered.count) \(filtered.count == 1 ? "trip" : "trips")")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.mileageSecondary)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, trip in
                            if index > 0 {
                                Divider().overlay(Color.mileageSeparator)
                                    .padding(.leading, dynamicTypeSize.isAccessibilitySize ? MileageTokens.Space.lg : 64)
                            }
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
            .padding(MileageTokens.Space.xl)
        }
        .background(Color.mileageBackground)
        .foregroundStyle(Color.mileagePrimary)
        .navigationTitle("Trip history")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.mileageBackground, for: .navigationBar)
        .toolbar(.visible, for: .navigationBar)
        .searchable(text: $query, prompt: "Search purpose or notes")
        .scrollDismissesKeyboard(.interactively)
    }
}
