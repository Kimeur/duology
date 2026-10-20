import SwiftUI

/// Places two views in the regions a fold makes: the video first, the controls second.
///
/// One layout type in every pose, so SwiftUI never rebuilds either view: the video
/// layer and the controls keep their identity, and playback never restarts when
/// the phone folds. The geometry is `FoldRegions` (Model/FoldRegions.swift).
struct FoldRegionsLayout: Layout {
    var fold: FoldGeometry

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let video = subviews[0]
        let controls = subviews[1]
        if let regions = FoldRegions.split(bounds, fold: fold) {
            video.place(at: regions.video.origin, proposal: ProposedViewSize(regions.video.size))
            // The controls keep their own size and sit in the middle of their region.
            controls.place(at: CGPoint(x: regions.controls.midX, y: regions.controls.midY), anchor: .center,
                           proposal: ProposedViewSize(regions.controls.size))
        } else {
            video.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
            let height = controls.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
            controls.place(at: CGPoint(x: bounds.midX, y: bounds.maxY), anchor: .bottom,
                           proposal: ProposedViewSize(width: bounds.width, height: height))
        }
    }
}
