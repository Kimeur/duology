import Foundation

// The column math from Duology's `duo-design-system` skill (references/grid.md), without
// SwiftUI, so Tools/run-model-tests.sh checks it on the Mac. Shared/FoldPanes.swift reads
// the fold from a GeometryProxy and turns these columns into two panes.

/// A fold that runs top to bottom through a view, in that view's coordinates.
/// Only x values are kept, so scrolling never changes it.
nonisolated struct DuoFold: Equatable, Sendable {
    var minX: CGFloat
    var maxX: CGFloat
    /// True while the phone is partly folded. Flat, the fold is still there, inactive.
    var isActive: Bool
}

/// Column positions of a layout grid, in the grid's own coordinates.
nonisolated struct DuoColumns: Equatable, Sendable {
    struct Column: Equatable, Sendable {
        var x: CGFloat
        var width: CGFloat
        var maxX: CGFloat { x + width }
    }

    private(set) var columns: [Column]
    /// Index of the first column after the fold, or nil when the fold doesn't
    /// split the grid. Groups never cross it.
    private(set) var split: Int?

    /// With a fold, `count` is rounded down to even and each side of the fold gets
    /// half the columns. Flat, the gap at the fold is one gutter centred on it;
    /// partly folded, it is the fold's frame. If one side is too narrow for its
    /// half at `minimumColumn`, every column goes on the other side and the fold
    /// becomes the grid's edge.
    init(width: CGFloat, count: Int, gutter: CGFloat, fold: DuoFold? = nil,
         minimumColumn: CGFloat = 44) {
        guard let fold else {
            columns = Self.row(from: 0, to: width, count: max(1, count), gutter: gutter)
            split = nil
            return
        }
        let count = max(2, count - count % 2)
        let half = count / 2
        let gapStart = fold.isActive ? fold.minX : (fold.minX + fold.maxX - gutter) / 2
        let gapEnd = fold.isActive ? fold.maxX : gapStart + gutter
        // Decided on the fold's frame, which has the same size flat and folded,
        // so the choice doesn't flip when the phone folds.
        func holdsHalf(_ length: CGFloat) -> Bool {
            length - CGFloat(half - 1) * gutter >= CGFloat(half) * minimumColumn
        }
        if holdsHalf(fold.minX), holdsHalf(width - fold.maxX) {
            columns = Self.row(from: 0, to: gapStart, count: half, gutter: gutter)
                + Self.row(from: gapEnd, to: width, count: half, gutter: gutter)
            split = half
        } else if fold.minX > width - fold.maxX {
            columns = Self.row(from: 0, to: gapStart, count: count, gutter: gutter)
            split = nil
        } else {
            columns = Self.row(from: gapEnd, to: width, count: count, gutter: gutter)
            split = nil
        }
    }

    private static func row(from start: CGFloat, to end: CGFloat,
                            count: Int, gutter: CGFloat) -> [Column] {
        let each = max(0, (end - start - CGFloat(count - 1) * gutter) / CGFloat(count))
        return (0..<count).map { Column(x: start + CGFloat($0) * (each + gutter), width: each) }
    }

    /// Merges every `span` columns into one. Each side of the fold is grouped
    /// on its own, so no group crosses it.
    func grouped(by span: Int) -> DuoColumns {
        let span = max(1, span)
        guard span > 1, !columns.isEmpty else { return self }
        let sides = split.map { [columns[..<$0], columns[$0...]] } ?? [columns[...]]
        var result = self
        result.columns = []
        for (index, side) in sides.enumerated() {
            if index == 1 { result.split = result.columns.count }
            var start = side.startIndex
            while start < side.endIndex {
                let last = min(start + span, side.endIndex) - 1
                result.columns.append(Column(x: side[start].x, width: side[last].maxX - side[start].x))
                start += span
            }
        }
        return result
    }

    /// Empty space before the first column. Not zero only when the fold is the
    /// grid's leading edge.
    var leadingInset: CGFloat { columns.first?.x ?? 0 }
}

/// Two panes made of half the grid's columns each. With a fold across the view, the
/// leading pane ends where the middle gap starts and the trailing pane starts where it
/// ends: one gutter centred on the fold line when the phone is flat, the fold's frame
/// when it is partly folded.
nonisolated struct PaneFrames: Equatable, Sendable {
    var leading: DuoColumns.Column
    var trailing: DuoColumns.Column
    var gap: CGFloat { trailing.x - leading.maxX }

    init(leading: DuoColumns.Column, trailing: DuoColumns.Column) {
        self.leading = leading
        self.trailing = trailing
    }

    /// Nil when the width is zero (before the first layout pass) or `count` is below 2.
    init?(width: CGFloat, count: Int, gutter: CGFloat, fold: DuoFold?) {
        guard width > 0, count >= 2 else { return nil }
        let even = count - count % 2
        let grid = DuoColumns(width: width, count: even, gutter: gutter, fold: fold).grouped(by: even / 2)
        guard grid.columns.count == 2 else { return nil }
        self.init(leading: grid.columns[0], trailing: grid.columns[1])
    }
}
