import SwiftUI

struct TripCard: View {
    @Binding var trip: Trip
    let isOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LinearGradient(colors: trip.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: isOpen ? 160 : 140)
                .overlay(alignment: .topTrailing) {
                    Button {
                        trip.isFavorite.toggle()
                    } label: {
                        Image(systemName: trip.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(.black.opacity(0.3)))
                    }
                    .accessibilityLabel(trip.isFavorite ? "Remove \(trip.city) from favorites" : "Add \(trip.city) to favorites")
                    .accessibilityIdentifier("trip.favorite.\(trip.id)")
                    .padding(10)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.city)
                    .font(.system(size: isOpen ? 20 : 17, weight: .semibold))
                    .foregroundStyle(.black)
                Text(trip.dates)
                    .font(.system(size: isOpen ? 15 : 13))
                    .foregroundStyle(Color(white: 0.7))
                Text(trip.note)
                    .font(.system(size: isOpen ? 15 : 13))
                    .foregroundStyle(Color(white: 0.45))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(isOpen ? 20 : 14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 55, style: .continuous))
    }
}
