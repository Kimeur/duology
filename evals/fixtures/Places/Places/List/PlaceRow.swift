import SwiftUI
import UIKit

struct PlaceRow: View {
    let place: Place

    var body: some View {
        // Thumbnail is a fifth of the screen width.
        let side = UIScreen.main.bounds.width / 5
        HStack(spacing: 12) {
            Image(systemName: place.symbol)
                .font(.title)
                .frame(width: side, height: side * 0.75)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.15)))
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)
                Text(place.region)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if place.visited {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}
