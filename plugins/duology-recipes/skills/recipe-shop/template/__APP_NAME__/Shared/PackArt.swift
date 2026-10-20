import SwiftUI

/// A pack's artwork: a deep gradient from its hue with its symbol. Drawn, not bundled, so the
/// template ships no images. Replace it with real artwork when you have some.
struct PackArt: View {
    let pack: Pack
    var cornerRadius: CGFloat = 16

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        shape
            .fill(
                LinearGradient(colors: [Self.top(pack.hue), Self.bottom(pack.hue)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay {
                // Fills a share of the art at any size, so a tile and the detail's hero
                // both look right.
                GeometryReader { proxy in
                    Image(systemName: pack.symbol)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(width: proxy.size.width * 0.38, height: proxy.size.height * 0.38)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                }
            }
            .overlay(shape.strokeBorder(.white.opacity(0.08), lineWidth: 1))
            .accessibilityHidden(true)
    }

    static func top(_ hue: Double) -> Color {
        Color(hue: hue, saturation: 0.52, brightness: 0.66)
    }

    static func bottom(_ hue: Double) -> Color {
        Color(hue: (hue + 0.04).truncatingRemainder(dividingBy: 1), saturation: 0.74, brightness: 0.34)
    }
}

/// A small label on artwork or next to a price: "New", "Owned", "Plus".
struct Badge: View {
    let text: String
    var symbol: String?
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: DuoSpace.x1) {
            if let symbol {
                Image(systemName: symbol)
            }
            Text(text)
        }
        .font(DuoType.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, DuoSpace.x2)
        .padding(.vertical, 3)
        .background(tint.opacity(0.14), in: Capsule())
    }
}

extension Pack {
    /// "4 sounds · 2 h" in the person's locale.
    var lengthText: String {
        let sounds = tracks.count == 1 ? "1 sound" : "\(tracks.count) sounds"
        let length = duration.formatted(.units(allowed: [.hours, .minutes], width: .narrow))
        return "\(sounds) · \(length)"
    }
}

/// What a pack's price slot says, from what the person owns and the basket.
enum PackState: Equatable {
    case owned, plus, inBasket, forSale
}

extension ShopModel {
    func state(of pack: Pack) -> PackState {
        if ownership.bought(pack.id) { return .owned }
        if ownership.hasPlus { return .plus }
        if cart.contains(pack.id) { return .inBasket }
        return .forSale
    }
}
