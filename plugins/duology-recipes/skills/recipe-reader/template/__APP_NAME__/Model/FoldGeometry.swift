import CoreGraphics
import Foundation

/// Where the fold crosses a view, read from the view's `.division` reserved regions.
///
/// Layout input only: never lay out from the hinge angle or status. The SwiftUI
/// half (`init(_ proxy:)` and `onFoldChange`) is in Shared/FoldReader.swift; this
/// half needs only Foundation and CoreGraphics, so the choice of fold is tested on the Mac.
/// Same type as duo-postures' references/fold-regions.md.
nonisolated struct FoldGeometry: Equatable, Sendable {
    /// The fold's frame in this view's space, margins included. Nil when no fold
    /// splits the view in two (the closed phone, or a fold beside the view).
    var frame: CGRect?
    /// True while the phone is partly folded. False when it lies flat.
    var isActive = false

    /// True when the fold runs top to bottom, so the view has a left part and a right part.
    var isVertical: Bool {
        guard let frame else { return false }
        return frame.height > frame.width
    }

    init(frame: CGRect? = nil, isActive: Bool = false) {
        self.frame = frame
        self.isActive = isActive
    }

    /// Picks the fold from what a region query returned: an active one first, and
    /// only one that splits a view of `size` into two parts.
    init(candidates: [(frame: CGRect, isActive: Bool)], in size: CGSize) {
        let inside = candidates.filter { Self.liesInside($0.frame, of: size) }
        if let fold = inside.first(where: \.isActive) ?? inside.first {
            frame = fold.frame
            isActive = fold.isActive
        }
    }

    /// True when a fold frame splits a view of `size` into two non-empty parts.
    /// A region query can return regions outside the view (measured for cameras
    /// on the closed phone), and a pane beside the fold must not read as folded.
    static func liesInside(_ frame: CGRect, of size: CGSize) -> Bool {
        if frame.height > frame.width {
            return frame.minX > 0 && frame.maxX < size.width
        }
        return frame.minY > 0 && frame.maxY < size.height
    }
}
