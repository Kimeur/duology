import SwiftUI

extension Tint {
    /// System colours, so pictures follow dark mode and Increase Contrast.
    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        }
    }
}

/// Draws an `Art` as large as the space it gets.
struct ArtView: View {
    let art: Art

    var body: some View {
        switch art {
        case .number(let value):
            bigText("\(value)")
        case .letter(let letter):
            bigText(letter)
        case .symbol(let name, let tint):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .foregroundStyle(tint.color)
        case .group(let name, let count, let one, let tint):
            group(name, count: count, one: one, tint: tint)
        }
    }

    /// A number or a letter, scaled to fill its frame.
    private func bigText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 400, weight: .heavy, design: .rounded))
            .minimumScaleFactor(0.05)
            .lineLimit(1)
            .foregroundStyle(.primary)
    }

    /// `count` symbols in one or two rows. Each is its own VoiceOver element ("star"),
    /// so a child using VoiceOver can count them by swiping.
    private func group(_ name: String, count: Int, one: String, tint: Tint) -> some View {
        let perRow = count <= 3 ? count : (count + 1) / 2
        let rows = stride(from: 0, to: count, by: max(perRow, 1)).map { start in
            Array(start..<min(start + perRow, count))
        }
        return VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { _ in
                        Image(systemName: name)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(tint.color)
                            .accessibilityLabel(one)
                    }
                }
            }
        }
    }
}
