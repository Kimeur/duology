import CoreGraphics
import Foundation

/// Where the two panes of a screen go: the first (the question, or the welcome) and the
/// second (the answers, or the activity cards), from the screen's size and the fold.
///
/// - A fold that runs top to bottom, flat or folded (open and held wide, or like a book):
///   first pane on the left page, second on the right, the fold's frame between them.
/// - A fold that runs side to side, flat or folded (open and held tall, or tabletop):
///   first pane above the fold, second below it, on the half that rests on the table.
/// - No fold (the closed phone): stacked when taller than wide, side by side when wider.
///
/// Flat and folded give the same regions, so folding moves nothing. Two inputs, the size
/// and the fold; never the device or a pose name. Pure geometry, tested on the Mac.
nonisolated struct LessonLayout: Equatable, Sendable {
    nonisolated enum Mode: String, Sendable {
        case stacked, sideBySide, foldLeftRight, foldTopBottom
    }

    let mode: Mode
    let first: CGRect
    let second: CGRect

    /// - Parameters:
    ///   - firstShare: the first pane's share of the space when no fold splits the screen.
    ///     A fold always splits where it is.
    ///   - spacing: the gap between the panes when no fold splits the screen.
    init(size: CGSize, fold: FoldGeometry, firstShare: CGFloat = 0.5, spacing: CGFloat = 16) {
        let share = min(max(firstShare, 0.2), 0.8)
        if let f = fold.frame, Self.crossesMiddle(f, vertical: fold.isVertical, of: size) {
            if fold.isVertical {
                mode = .foldLeftRight
                first = CGRect(x: 0, y: 0, width: f.minX, height: size.height)
                second = CGRect(x: f.maxX, y: 0, width: max(0, size.width - f.maxX), height: size.height)
            } else {
                mode = .foldTopBottom
                first = CGRect(x: 0, y: 0, width: size.width, height: f.minY)
                second = CGRect(x: 0, y: f.maxY, width: size.width, height: max(0, size.height - f.maxY))
            }
        } else if size.width > size.height {
            let width = max(0, size.width - spacing)
            mode = .sideBySide
            first = CGRect(x: 0, y: 0, width: width * share, height: size.height)
            second = CGRect(x: width * share + spacing, y: 0, width: width * (1 - share), height: size.height)
        } else {
            let height = max(0, size.height - spacing)
            mode = .stacked
            first = CGRect(x: 0, y: 0, width: size.width, height: height * share)
            second = CGRect(x: 0, y: height * share + spacing, width: size.width, height: height * (1 - share))
        }
    }

    /// A fold counts only when it crosses the middle half of the screen. A fold at the very
    /// edge (a window beside it in Split View) would leave one pane a sliver.
    static func crossesMiddle(_ fold: CGRect, vertical: Bool, of size: CGSize) -> Bool {
        let line = vertical ? fold.midX : fold.midY
        let length = vertical ? size.width : size.height
        return line > length / 4 && line < length * 3 / 4
    }
}
