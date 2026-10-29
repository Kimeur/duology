import SwiftUI

/// Places the note's editor and its summary in `NoteLayout`'s regions: the first view in
/// `editor`, the second in `summary`. One layout in every pose, so neither view is rebuilt when
/// the phone opens, closes or folds: the text being typed, the cursor and the scroll position stay.
///
/// Read the fold with `.onFoldChange` on this layout itself, so the fold's frame and the
/// regions share one coordinate space.
struct PaneSplit: Layout {
    var fold: FoldGeometry
    var barHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let layout = NoteLayout(size: bounds.size, fold: fold, barHeight: barHeight)
        for (subview, region) in zip(subviews, [layout.editor, layout.summary]) {
            subview.place(at: CGPoint(x: bounds.minX + region.minX, y: bounds.minY + region.minY),
                          proposal: ProposedViewSize(region.size))
        }
    }
}

/// Places one row of the notes list: the first view in the first column, and so on.
/// The columns come from `NoteColumns`, in the row's own space.
struct ColumnsRow: Layout {
    var columns: [ClosedRange<CGFloat>]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = zip(subviews, columns).map { subview, column in
            subview.sizeThatFits(ProposedViewSize(width: column.upperBound - column.lowerBound, height: nil)).height
        }.max() ?? 0
        return CGSize(width: proposal.width ?? (columns.last?.upperBound ?? 0), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, column) in zip(subviews, columns) {
            subview.place(at: CGPoint(x: bounds.minX + column.lowerBound, y: bounds.minY),
                          proposal: ProposedViewSize(width: column.upperBound - column.lowerBound, height: bounds.height))
        }
    }
}
