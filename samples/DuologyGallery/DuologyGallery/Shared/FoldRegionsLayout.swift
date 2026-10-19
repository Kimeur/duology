import SwiftUI

/// Places two views in the regions a fold makes: content first, controls second.
/// Fold top to bottom (book): content leading, controls trailing.
/// Fold side to side (tabletop): content on top, controls below.
/// One layout in every pose, so both views keep their identity and state:
/// a video keeps playing and a scroll view keeps its place through a fold.
///
/// Same layout as the `duo-postures` skill's `references/fold-regions.md`.
/// This copy builds for iOS 26: it only reads `FoldGeometry`, which stays
/// empty before iOS 27.1, so earlier systems always get the unfolded case.
struct FoldRegionsLayout: Layout {
    enum Unfolded: Sendable {
        /// No active fold: controls float over the content at the bottom, like a ZStack.
        case overlay
        /// Split even when flat: at the fold line on the inner display, so folding
        /// moves nothing; in the middle, side by side or stacked, on the outer display.
        case split
    }

    var fold: FoldGeometry
    var unfolded: Unfolded = .overlay
    var spacing: CGFloat = 16

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let content = subviews[0]
        let controls = subviews[1]
        if let (first, second) = regions(in: bounds) {
            content.place(at: first.origin, proposal: ProposedViewSize(first.size))
            controls.place(at: CGPoint(x: second.midX, y: second.midY), anchor: .center,
                           proposal: ProposedViewSize(second.size))
        } else {
            content.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
            let height = controls.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
            controls.place(at: CGPoint(x: bounds.midX, y: bounds.maxY), anchor: .bottom,
                           proposal: ProposedViewSize(width: bounds.width, height: height))
        }
    }

    /// The content region and the controls region, or nil to overlay.
    func regions(in bounds: CGRect) -> (CGRect, CGRect)? {
        // Region frames are in this view's own space; bounds can start anywhere.
        if let f = fold.frame, fold.isActive || unfolded == .split {
            let vertical = fold.isVertical
            let line = vertical ? f.midX : f.midY
            let length = vertical ? bounds.width : bounds.height
            // Use the fold only when it crosses the middle half of this view.
            // A fold at the very edge (a pane beside it) would leave one region empty.
            if line > length / 4, line < length * 3 / 4 {
                if vertical {
                    return (CGRect(x: bounds.minX, y: bounds.minY, width: f.minX, height: bounds.height),
                            CGRect(x: bounds.minX + f.maxX, y: bounds.minY,
                                   width: bounds.width - f.maxX, height: bounds.height))
                }
                return (CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: f.minY),
                        CGRect(x: bounds.minX, y: bounds.minY + f.maxY,
                               width: bounds.width, height: bounds.height - f.maxY))
            }
        }
        guard unfolded == .split else { return nil }
        // No fold in this view (the outer display): split in the middle.
        if bounds.width >= bounds.height {
            let width = (bounds.width - spacing) / 2
            return (CGRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height),
                    CGRect(x: bounds.maxX - width, y: bounds.minY, width: width, height: bounds.height))
        }
        let height = (bounds.height - spacing) / 2
        return (CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: height),
                CGRect(x: bounds.minX, y: bounds.maxY - height, width: bounds.width, height: height))
    }
}
