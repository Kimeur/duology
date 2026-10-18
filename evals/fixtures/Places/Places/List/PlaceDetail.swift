import SwiftUI
import UIKit

struct PlaceDetail: View {
    let place: Place
    @State private var isFavorite = false

    var body: some View {
        GeometryReader { proxy in
            // Small phones (iPhone SE) get a shorter header.
            let compactHeader = proxy.size.width <= 375
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack {
                        LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: place.symbol)
                            .font(.system(size: 64))
                            .foregroundStyle(.white)
                    }
                    .frame(height: compactHeader ? 160 : UIScreen.main.bounds.height * 0.3)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(place.name)
                            .font(.largeTitle.bold())
                        Text(place.region)
                            .foregroundStyle(.secondary)
                        Text(place.summary)
                            .font(.body)
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { index in
                                Image(systemName: index < place.rating ? "star.fill" : "star")
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 80)
            }
        }
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            // Our own action bar, styled like the system one.
            HStack {
                Button { } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                Spacer()
                Button("Directions") { }
                Spacer()
                Button {
                    isFavorite.toggle()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                }
            }
            .font(.title3)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }
}
