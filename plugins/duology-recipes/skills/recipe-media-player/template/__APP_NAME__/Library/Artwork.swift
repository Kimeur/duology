import SwiftUI

/// Show artwork drawn from the catalogue: the show's two colours and its symbol.
/// Swap it for `AsyncImage` when your catalogue has image URLs.
struct Artwork: View {
    let show: Show
    var episodeNumber: Int?

    var body: some View {
        let colors = show.colors.map(Color.init(hex:))
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: colors.isEmpty ? [.gray, .black] : colors,
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                Image(systemName: show.symbol)
                    .font(.system(size: side * 0.42, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let episodeNumber {
                Text("Episode \(episodeNumber)")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(14)
            }
        }
        .accessibilityHidden(true)
    }
}
