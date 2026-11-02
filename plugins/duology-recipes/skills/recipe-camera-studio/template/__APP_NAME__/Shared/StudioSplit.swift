import SwiftUI

/// Places the preview and the controls in `StudioLayout`'s regions: the first view in `preview`,
/// the second in `controls`. One layout in every pose, so the preview's view (and with it the
/// camera's preview layer and its coordinators) is never rebuilt when the phone opens, closes
/// or folds.
///
/// Read the fold with `.onFoldChange` on this layout itself, so the fold's frame and the
/// regions share one coordinate space.
struct StudioSplit: Layout {
    var fold: FoldGeometry
    var controlsThickness: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let layout = StudioLayout(size: bounds.size, fold: fold, controlsThickness: controlsThickness)
        for (subview, region) in zip(subviews, [layout.preview, layout.controls]) {
            subview.place(at: CGPoint(x: bounds.minX + region.minX, y: bounds.minY + region.minY),
                          proposal: ProposedViewSize(region.size))
        }
    }
}
