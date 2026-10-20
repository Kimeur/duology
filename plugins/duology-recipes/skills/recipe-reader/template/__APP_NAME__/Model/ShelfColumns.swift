import CoreGraphics
import Foundation

/// Columns for the shelf of covers in the library.
///
/// With no fold, as many columns as fit. When a top-to-bottom fold crosses the shelf,
/// flat or folded, each side gets the same number of columns and the fold's frame is
/// the gap between them, so no cover sits on the fold and the count is always even.
/// Pure geometry, tested on the Mac.
nonisolated struct ShelfColumns: Equatable, Sendable {
    nonisolated struct Column: Equatable, Sendable {
        var minX: CGFloat
        var width: CGFloat
        var maxX: CGFloat { minX + width }
    }

    let columns: [Column]
    /// True when a fold splits the columns into two equal groups.
    let isSplit: Bool

    var count: Int { columns.count }
    /// The columns on the leading side of the fold, or all of them with no fold.
    /// Wide content, such as the Continue Reading card, spans these and stays off the fold.
    var leadingColumns: ArraySlice<Column> { isSplit ? columns.prefix(columns.count / 2) : columns[...] }
    /// Every column has the same width.
    var columnWidth: CGFloat { columns.first?.width ?? 0 }

    /// - Parameters:
    ///   - width: the shelf's width.
    ///   - fold: the fold in the shelf's own space.
    ///   - minWidth: the narrowest a cover may be.
    ///   - spacing: the gap between columns on one side of the fold.
    ///   - margin: the space at the shelf's outer edges.
    init(width: CGFloat, fold: FoldGeometry, minWidth: CGFloat, spacing: CGFloat, margin: CGFloat) {
        guard width > 2 * margin, minWidth > 0 else {
            columns = []
            isSplit = false
            return
        }
        if fold.isVertical, let f = fold.frame, f.minX > margin, f.maxX < width - margin {
            let leading = f.minX - margin
            let trailing = width - margin - f.maxX
            let perSide = max(1, min(Self.fit(leading, minWidth, spacing), Self.fit(trailing, minWidth, spacing)))
            let side = CGFloat(perSide)
            let columnWidth = max(0, (min(leading, trailing) - spacing * (side - 1)) / side)
            let block = columnWidth * side + spacing * (side - 1)
            // Each side's block sits in the middle of its side.
            let leadingStart = margin + (leading - block) / 2
            let trailingStart = f.maxX + (trailing - block) / 2
            columns = (0..<perSide).map { Column(minX: leadingStart + CGFloat($0) * (columnWidth + spacing), width: columnWidth) }
                + (0..<perSide).map { Column(minX: trailingStart + CGFloat($0) * (columnWidth + spacing), width: columnWidth) }
            isSplit = true
        } else {
            let available = width - 2 * margin
            let count = max(1, Self.fit(available, minWidth, spacing))
            let columnWidth = (available - spacing * CGFloat(count - 1)) / CGFloat(count)
            columns = (0..<count).map { Column(minX: margin + CGFloat($0) * (columnWidth + spacing), width: columnWidth) }
            isSplit = false
        }
    }

    /// How many columns of at least `minWidth`, `spacing` apart, fit in `width`.
    private static func fit(_ width: CGFloat, _ minWidth: CGFloat, _ spacing: CGFloat) -> Int {
        Int(((width + spacing) / (minWidth + spacing)).rounded(.down))
    }
}
