import SwiftUI

/// A big rounded tile: a picture that fills it, and a caption under it. Answers, Next,
/// Play Again and the home screen's buttons all use it, so every target looks alike.
struct BigTile: View {
    let art: Art
    var caption: String?
    let size: CGSize

    var body: some View {
        VStack(spacing: 8) {
            ArtView(art: art)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)      // the button carries the label
            if let caption {
                Text(caption)
                    .font(.title2.bold())
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }
        }
        .padding(12)
        .frame(width: size.width, height: size.height)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.systemBackground)))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// A press that dims, and shrinks a little unless Reduce Motion is on.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// A row of big tiles laid out by `AnswerGrid` in the space measured for them.
struct TileGrid<Item: Identifiable, Tile: View>: View {
    let items: [Item]
    let space: CGSize
    @ViewBuilder let tile: (Item, CGSize) -> Tile

    var body: some View {
        let grid = AnswerGrid(count: items.count, in: space)
        VStack(spacing: grid.spacing) {
            ForEach(0..<grid.rows, id: \.self) { row in
                HStack(spacing: grid.spacing) {
                    ForEach(items[row * grid.columns ..< (row + 1) * grid.columns]) { item in
                        tile(item, grid.button)
                    }
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }
}
