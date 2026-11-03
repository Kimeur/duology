import CoreGraphics
import Foundation

/// Where the camera preview and the controls go, from the screen's size and the fold.
///
/// - Folded like a book (a fold that runs top to bottom and is active): the preview on the
///   left page, the controls on the right, the fold's frame between them.
/// - Tabletop (a fold that runs side to side and is active): the preview above the fold, the
///   controls below it, on the half that rests on the table.
/// - Otherwise (closed, or open and flat): the preview fills the screen and the controls float
///   over it, along the bottom edge when the screen is taller than wide, along the trailing
///   edge when it is wider. Flat, the fold is inactive, so the preview may cross it; the
///   controls never do.
///
/// This is what Apple's `ArrangementView` with the overlay style does (measured in
/// `duo-camera`), written as plain geometry so it runs below iOS 27.1 and is tested on the
/// Mac. Two inputs, the size and the fold; never the device or a pose name.
nonisolated struct StudioLayout: Equatable, Sendable {
    nonisolated enum Mode: String, Sendable {
        case floating, foldLeftRight, foldTopBottom
    }

    nonisolated enum ControlsEdge: String, Sendable {
        case bottom, trailing
    }

    let mode: Mode
    let preview: CGRect
    let controls: CGRect
    /// Which way the controls run: a row along the bottom, or a column along the trailing edge.
    let edge: ControlsEdge

    /// True when the controls sit over the preview rather than beside it.
    var controlsFloat: Bool { mode == .floating }

    /// The floating bar's height, or the floating column's width, at the default text size.
    static let controlsThickness: CGFloat = 132

    init(size: CGSize, fold: FoldGeometry, controlsThickness: CGFloat = StudioLayout.controlsThickness) {
        let thickness = min(max(controlsThickness, 88), min(size.width, size.height) / 2)
        if let f = fold.frame, fold.isActive, Self.crossesMiddle(f, vertical: fold.isVertical, of: size) {
            if fold.isVertical {
                mode = .foldLeftRight
                edge = .trailing
                preview = CGRect(x: 0, y: 0, width: f.minX, height: size.height)
                controls = CGRect(x: f.maxX, y: 0, width: max(0, size.width - f.maxX), height: size.height)
            } else {
                mode = .foldTopBottom
                edge = .bottom
                preview = CGRect(x: 0, y: 0, width: size.width, height: f.minY)
                controls = CGRect(x: 0, y: f.maxY, width: size.width, height: max(0, size.height - f.maxY))
            }
        } else {
            mode = .floating
            preview = CGRect(origin: .zero, size: size)
            if size.width > size.height {
                edge = .trailing
                controls = CGRect(x: size.width - thickness, y: 0, width: thickness, height: size.height)
            } else {
                edge = .bottom
                controls = CGRect(x: 0, y: size.height - thickness, width: size.width, height: thickness)
            }
        }
    }

    /// A fold counts only when it crosses the middle half of the screen. A fold at the very
    /// edge (a window beside it in Split View) would leave one region a sliver.
    static func crossesMiddle(_ fold: CGRect, vertical: Bool, of size: CGSize) -> Bool {
        let line = vertical ? fold.midX : fold.midY
        let length = vertical ? size.width : size.height
        return line > length / 4 && line < length * 3 / 4
    }
}
