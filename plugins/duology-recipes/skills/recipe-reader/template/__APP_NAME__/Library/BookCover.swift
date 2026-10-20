import SwiftUI

/// A cover drawn from the book's colours: kind, title and author on a gradient.
/// Swap it for an image when your books have cover art.
struct BookCover: View {
    let book: Book
    /// A thumbnail (the Continue Reading card): the title's first letter only, since
    /// the title sits right next to it.
    var compact = false

    var body: some View {
        let colors = book.colors.map(Color.init(hex:))
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: colors.isEmpty ? [.gray, .black] : colors,
                           startPoint: .top, endPoint: .bottom)
            if compact {
                Text(book.title.prefix(1))
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(book.kind)
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.75))
                    Text(book.title)
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(5)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(.white.opacity(0.55))
                        .frame(width: 28, height: 2)
                    Text(book.author)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                }
                .padding(14)
            }
            // The spine: a soft shadow down the left edge.
            LinearGradient(colors: [.black.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: compact ? 6 : 12)
        }
        // A cover is a picture: its text stays the same size at every text size.
        .dynamicTypeSize(.large)
        .clipShape(.rect(cornerRadius: compact ? 6 : 10))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        .accessibilityHidden(true)
    }
}
