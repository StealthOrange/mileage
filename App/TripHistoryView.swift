import SwiftUI

struct TripHistoryView: View {
    @EnvironmentObject private var store: MileageStore
    @State private var filter = "All"
    @State private var query = ""

    private var filtered: [Trip] {
        store.completedTrips.filter {
            (filter == "All" || $0.category.rawValue == filter || (filter == "Review" && $0.needsReview)) &&
            (query.isEmpty || "\($0.purpose) \($0.notes)".localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Filter trips", selection: $filter) {
                    ForEach(["All", "Business", "Personal", "Review"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented)
                if filtered.isEmpty {
                    ContentUnavailableView("No trips found", systemImage: "car", description: Text("Completed trips will appear here."))
                }
                ForEach(filtered) { trip in
                    NavigationLink { TripDetailView(tripID: trip.id) } label: { TripRow(trip: trip) }.buttonStyle(.plain)
                }
            }.padding(20)
        }
        .background(Color.mileageBackground)
        .navigationTitle("Trip history")
        .searchable(text: $query, prompt: "Search purpose or notes")
    }
}
