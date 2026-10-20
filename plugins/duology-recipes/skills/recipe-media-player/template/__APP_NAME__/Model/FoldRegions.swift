import CoreGraphics
import Foundation

/// Where the player's two parts go: the video first, the controls second.
///
/// - No active fold (closed, or open and flat): no regions; the controls float
///   over the video at the bottom.
/// - Fold top to bottom (book): video in the leading region, controls trailing.
/// - Fold side to side (tabletop): video above the fold, controls below it.
///
/// Pure geometry, used by FoldRegionsLayout and tested on the Mac.
nonisolated enum FoldRegions {
    /// The video region and the controls region, or nil when the controls should
    /// float over the video. `bounds` is the layout's frame; the fold frame is in
    /// the same view's own space, so it is offset by `bounds.origin`.
    static func split(_ bounds: CGRect, fold: FoldGeometry) -> (video: CGRect, controls: CGRect)? {
        guard fold.isActive, let f = fold.frame else { return nil }
        let vertical = fold.isVertical
        let line = vertical ? f.midX : f.midY
        let length = vertical ? bounds.width : bounds.height
        // Use the fold only when it crosses the middle half of the view. A fold at
        // the very edge (a window beside it) would leave one region empty.
        guard line > length / 4, line < length * 3 / 4 else { return nil }
        if vertical {
            return (CGRect(x: bounds.minX, y: bounds.minY, width: f.minX, height: bounds.height),
                    CGRect(x: bounds.minX + f.maxX, y: bounds.minY,
                           width: bounds.width - f.maxX, height: bounds.height))
        }
        return (CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: f.minY),
                CGRect(x: bounds.minX, y: bounds.minY + f.maxY,
                       width: bounds.width, height: bounds.height - f.maxY))
    }

    /// Where a floating bar (the mini player) may sit in a view of `size`: the
    /// whole width, or the part trailing a top-to-bottom fold. The fold counts
    /// even while the phone is flat, so the bar doesn't jump when someone folds it.
    static func floatingBarSpan(width: CGFloat, fold: FoldGeometry) -> (minX: CGFloat, maxX: CGFloat) {
        guard fold.isVertical, let f = fold.frame, f.maxX < width else { return (0, width) }
        return (f.maxX, width)
    }

    /// The largest rectangle with `aspect` (width over height) that fits in `size`, centred.
    static func fit(aspect: CGFloat, in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0, aspect > 0 else { return .zero }
        var width = size.width
        var height = width / aspect
        if height > size.height {
            height = size.height
            width = height * aspect
        }
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    /// The video's frame in a view of `size` when the controls cover `covered`
    /// points of its bottom edge: centred in the space above them when the whole
    /// picture fits there (the closed phone, held upright), else centred in the view.
    static func picture(aspect: CGFloat, in size: CGSize, covered: CGFloat) -> CGRect {
        let picture = fit(aspect: aspect, in: size)
        let free = size.height - covered
        guard covered > 0, picture.height <= free else { return picture }
        return picture.offsetBy(dx: 0, dy: (free - picture.height) / 2 - picture.minY)
    }
}
