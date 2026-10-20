import SwiftUI

/// The library: the book you were reading, then a shelf of covers.
///
/// The shelf reads the fold even while the phone lies flat. When a fold crosses it,
/// each side gets the same number of columns and the fold is the gap between them,
/// so no cover sits on the fold and nothing moves when the phone folds.
struct LibraryView: View {
    let store: LibraryStore
    @State private var fold = FoldGeometry()
    @State private var width: CGFloat = 0

    var body: some View {
        let shelf = ShelfColumns(width: width, fold: fold, minWidth: 140, spacing: 16, margin: 20)
        let leading = shelf.leadingColumns
        let leadingX = leading.first?.minX ?? 20
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let book = store.continueBook {
                    ContinueCard(book: book, store: store)
                        // On the leading side of the fold, so its button never sits on it.
                        .frame(width: max(0, (leading.last?.maxX ?? width - 20) - leadingX))
                        .padding(.leading, leadingX)
                }
                Text("All Books")
                    .font(.title2.bold())
                    .padding(.leading, leadingX)
                    .accessibilityAddTraits(.isHeader)
                ShelfLayout(shelf: shelf, rowSpacing: 28) {
                    ForEach(store.library.books) { book in
                        BookTile(book: book, store: store)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .onFoldChange { fold = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .navigationTitle("Library")
    }
}

/// Places covers in the shelf's columns, row by row. Each row is as tall as its
/// tallest tile, so titles that wrap at large text sizes push the next row down.
struct ShelfLayout: Layout {
    var shelf: ShelfColumns
    var rowSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rowHeights(subviews)
        let height = rows.reduce(0, +) + rowSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? (shelf.columns.last?.maxX ?? 0), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard shelf.count > 0 else { return }
        var y = bounds.minY
        for (row, height) in rowHeights(subviews).enumerated() {
            for column in 0..<shelf.count {
                let index = row * shelf.count + column
                guard subviews.indices.contains(index) else { break }
                let frame = shelf.columns[column]
                subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: y),
                                      proposal: ProposedViewSize(width: frame.width, height: height))
            }
            y += height + rowSpacing
        }
    }

    private func rowHeights(_ subviews: Subviews) -> [CGFloat] {
        guard shelf.count > 0 else { return [] }
        let proposal = ProposedViewSize(width: shelf.columnWidth, height: nil)
        return stride(from: 0, to: subviews.count, by: shelf.count).map { start in
            subviews[start..<min(start + shelf.count, subviews.count)]
                .map { $0.sizeThatFits(proposal).height }
                .max() ?? 0
        }
    }
}

/// One book on the shelf: its cover, title, author and how far you got.
struct BookTile: View {
    let book: Book
    let store: LibraryStore

    var body: some View {
        let progress = store.progress(of: book)
        let started = store.hasStarted(book)
        Button {
            store.open(book)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                BookCover(book: book)
                    .aspectRatio(2 / 3, contentMode: .fit)
                VStack(alignment: .leading, spacing: 3) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(3)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if started {
                        ProgressView(value: progress)
                            .padding(.top, 4)
                            .accessibilityHidden(true)
                    } else {
                        Text("New")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(started ? "\(Int((progress * 100).rounded())) percent read" : "New")
        .accessibilityIdentifier("library.book.\(book.id)")
    }
}

/// The book you read last, where you left it, with the words you'll read next.
struct ContinueCard: View {
    let book: Book
    let store: LibraryStore

    var body: some View {
        let position = store.position(of: book)
        let chapter = book.chapters[position.chapter]
        let progress = store.progress(of: book)
        Button {
            store.open(book)
        } label: {
            HStack(alignment: .top, spacing: 16) {
                BookCover(book: book, compact: true)
                    .frame(width: 72, height: 108)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Continue Reading")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.tint)
                    Text(book.title)
                        .font(.title3.bold())
                    Text("\(chapter.title) · \(Int((progress * 100).rounded()))% read")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(store.text(of: book, chapter: position.chapter).excerpt(at: position.offset))
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(.fill.tertiary, in: .rect(cornerRadius: 20))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the book where you left it")
        .accessibilityIdentifier("library.continue")
    }
}
