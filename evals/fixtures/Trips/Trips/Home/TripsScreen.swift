import SwiftUI
import UIKit

struct TripsScreen: View {
    @State private var trips = Trip.samples
    private let isOpen = UIScreen.main.bounds.width > 600

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: isOpen ? 28 : 20) {
                Text("Upcoming trips")
                    .font(.system(size: isOpen ? 34 : 28, weight: .bold))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: isOpen ? 3 : 1),
                          spacing: 16) {
                    ForEach($trips) { $trip in
                        TripCard(trip: $trip, isOpen: isOpen)
                    }
                }
                Button {
                } label: {
                    Text("Plan a trip")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("trips.plan")
            }
            .padding(.horizontal, isOpen ? 24 : 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
    }
}
