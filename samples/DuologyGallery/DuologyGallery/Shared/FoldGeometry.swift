import SwiftUI

/// Where the fold crosses a view, read from the view's reserved regions.
///
/// Layout input only. Never drive layout from the hinge angle: Apple keeps the
/// hinge for effects, and reserved regions for layout.
///
/// Same idea as the `FoldGeometry` helper in the `duo-patterns` skill. This copy
/// builds for iOS 26: the type is always there, and only reading it needs iOS 27.1.
nonisolated struct FoldGeometry: Equatable, Sendable {
    /// The fold's frame in this view's space, margins included. Nil when no fold
    /// lies inside the view, including a fold that only touches one of its edges.
    var frame: CGRect?
    /// True while the phone is partly folded. False when it lies flat.
    var isActive = false

    /// True when the fold runs top to bottom, so the view has a left half and a right half.
    var isVertical: Bool {
        guard let frame else { return false }
        return frame.height > frame.width
    }

    init(frame: CGRect? = nil, isActive: Bool = false) {
        self.frame = frame
        self.isActive = isActive
    }

    @available(iOS 27.1, *)
    init(_ proxy: GeometryProxy) {
        // The default query returns active regions only (measured on the iOS 27.1
        // simulator). Ask for inactive ones too, so a flat inner display still
        // tells you where its fold is.
        //
        // The query returns every region that intersects the view, so a fold
        // that only touches the view's edge comes back too. A Split View window
        // that ends at the fold might do that (not checked). Keep only a fold
        // that lies inside the view.
        let size = proxy.size
        let folds = proxy.reservedRegions(kind: .division, options: .includeInactive)
            .filter { Self.liesInside($0.frame, of: size) }
        if let fold = folds.first(where: \.isActive) ?? folds.first {
            frame = fold.frame
            isActive = fold.isActive
        }
    }

    /// True when a fold frame splits a view of `size` into two parts: a top to
    /// bottom fold with view on its left and right, or a side to side fold with
    /// view above and below. A pure function, so it can be tested on the Mac.
    static func liesInside(_ frame: CGRect, of size: CGSize) -> Bool {
        if frame.height > frame.width {
            return frame.minX > 0 && frame.maxX < size.width
        }
        return frame.minY > 0 && frame.maxY < size.height
    }

    /// A short description for the gallery's status labels.
    var summary: String {
        guard let frame else { return "No fold" }
        let state = isActive ? "active" : "inactive"
        let axis = isVertical ? "top to bottom" : "side to side"
        return "Fold \(state), \(axis), \(Int(frame.width)) × \(Int(frame.height)) pt"
    }
}

extension View {
    /// Calls `action` with the fold geometry now and every time it changes.
    /// On systems before iOS 27.1 it never calls `action`: there is no fold to read.
    func onFoldChange(_ action: @escaping (FoldGeometry) -> Void) -> some View {
        modifier(FoldChangeReader(action: action))
    }
}

private struct FoldChangeReader: ViewModifier {
    let action: (FoldGeometry) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onGeometryChange(for: FoldGeometry.self) { proxy in
                FoldGeometry(proxy)
            } action: { fold in
                action(fold)
            }
        } else {
            content
        }
    }
}

/// The part of a view where controls may sit: the whole view when flat or
/// closed, the trailing region when folded like a book, the bottom region when
/// folded across. Used by displacement and by the extended canvas tools.
///
/// SwiftUI mirrors region frames for right-to-left layouts by default, so
/// `maxX` is the trailing side in both directions.
func controlRegion(in size: CGSize, fold: FoldGeometry) -> CGRect {
    let whole = CGRect(origin: .zero, size: size)
    guard fold.isActive, let frame = fold.frame else { return whole }
    if fold.isVertical {
        return CGRect(x: frame.maxX, y: 0, width: max(0, size.width - frame.maxX), height: size.height)
    }
    return CGRect(x: 0, y: frame.maxY, width: size.width, height: max(0, size.height - frame.maxY))
}
