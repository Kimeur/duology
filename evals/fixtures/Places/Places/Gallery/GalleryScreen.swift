import SwiftUI
import UIKit

struct GalleryScreen: View {
    // Three columns in portrait, five in landscape.
    private var columns: [GridItem] {
        let count = UIDevice.current.orientation.isLandscape ? 5 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Place.samples) { place in
                        GalleryTile(place: place)
                    }
                }
                .padding(8)
            }
            .navigationTitle("Gallery")
        }
    }
}

struct GalleryTile: View {
    let place: Place

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.2))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: place.symbol)
                        .font(.largeTitle)
                }
            Text(place.name)
                .font(.caption.bold())
                .padding(6)
        }
    }
}
