import SwiftUI

/// Places two views in `LessonLayout`'s regions: the first view in `first`, the second in
/// `second`. One layout in every pose, so neither view is rebuilt when the phone opens,
/// closes or folds, and nothing they hold is lost.
///
/// Read the fold with `.onFoldChange` on this layout itself, so the fold's frame and the
/// regions share one coordinate space.
struct PaneSplit: Layout {
    var fold: FoldGeometry
    var firstShare: CGFloat = 0.5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let layout = LessonLayout(size: bounds.size, fold: fold, firstShare: firstShare)
        for (subview, region) in zip(subviews, [layout.first, layout.second]) {
            subview.place(at: CGPoint(x: bounds.minX + region.minX, y: bounds.minY + region.minY),
                          proposal: ProposedViewSize(region.size))
        }
    }
}
