import CoreGraphics
import Foundation

/// Where the note's editor and its summary go, from the screen's size and the fold.
///
/// - A fold that runs top to bottom, flat or folded (open and held wide, or like a book):
///   the note on the left page, the summary pane on the right, the fold's frame between them.
/// - A fold that runs side to side, flat or folded (open and held tall, or tabletop):
///   the note above the fold, the summary pane below it, on the half that rests on the table.
/// - No fold and room for two (a wide window, such as an iPad held sideways): side by side.
/// - Otherwise (the closed phone): the note, with the summary as a one-line bar at the bottom.
///
/// The second region always holds the summary view: the full pane, or the bar. Flat and folded
/// give the same regions, so folding moves nothing. Two inputs, the size and the fold; never the
/// device or a pose name. Pure geometry, tested on the Mac.
nonisolated struct NoteLayout: Equatable, Sendable {
    nonisolated enum Mode: String, Sendable {
        case single, sideBySide, foldLeftRight, foldTopBottom
    }

    let mode: Mode
    let editor: CGRect
    let summary: CGRect

    /// True when the summary has a pane of its own; false when it's the bar.
    var hasSummaryPane: Bool { mode != .single }

    /// The narrowest window that gets two panes without a fold. The closed phone held sideways
    /// (678 pt) stays single: two 330 pt panes beside a keyboard leave little to write in.
    static let twoPaneMinimumWidth: CGFloat = 700

    /// - Parameters:
    ///   - barHeight: the bar's height in single mode (it grows with the text size).
    ///   - editorShare: the note's share of the width when no fold splits the screen.
    init(size: CGSize, fold: FoldGeometry, barHeight: CGFloat, editorShare: CGFloat = 0.58, spacing: CGFloat = 16) {
        if let f = fold.frame, Self.crossesMiddle(f, vertical: fold.isVertical, of: size) {
            if fold.isVertical {
                mode = .foldLeftRight
                editor = CGRect(x: 0, y: 0, width: f.minX, height: size.height)
                summary = CGRect(x: f.maxX, y: 0, width: max(0, size.width - f.maxX), height: size.height)
            } else {
                mode = .foldTopBottom
                editor = CGRect(x: 0, y: 0, width: size.width, height: f.minY)
                summary = CGRect(x: 0, y: f.maxY, width: size.width, height: max(0, size.height - f.maxY))
            }
        } else if size.width >= Self.twoPaneMinimumWidth && size.width > size.height {
            let share = min(max(editorShare, 0.4), 0.7)
            let width = max(0, size.width - spacing)
            mode = .sideBySide
            editor = CGRect(x: 0, y: 0, width: width * share, height: size.height)
            summary = CGRect(x: width * share + spacing, y: 0, width: width * (1 - share), height: size.height)
        } else {
            let bar = min(max(barHeight, 0), size.height / 2)
            mode = .single
            editor = CGRect(x: 0, y: 0, width: size.width, height: max(0, size.height - bar))
            summary = CGRect(x: 0, y: size.height - bar, width: size.width, height: bar)
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

/// The columns of the notes list. Wherever a fold runs top to bottom through the list, flat or
/// folded, two columns meet at its frame, so no card ever lies on the fold. Otherwise as many
/// columns of at least `minimumWidth` as fit, up to three.
nonisolated struct NoteColumns: Equatable, Sendable {
    /// Each column's left edge and width, in the list's own space.
    let columns: [ClosedRange<CGFloat>]
    let foldsBetween: Bool

    static let minimumWidth: CGFloat = 280

    init(width: CGFloat, fold: FoldGeometry, margin: CGFloat = 16, gap: CGFloat = 12) {
        if let f = fold.frame, fold.isVertical, NoteLayout.crossesMiddle(f, vertical: true, of: CGSize(width: width, height: 1)) {
            columns = [margin...max(margin, f.minX - gap / 2), min(width - margin, f.maxX + gap / 2)...(width - margin)]
            foldsBetween = true
            return
        }
        let usable = max(0, width - 2 * margin)
        let count = max(1, min(3, Int((usable + gap) / (Self.minimumWidth + gap))))
        let column = (usable - gap * CGFloat(count - 1)) / CGFloat(count)
        columns = (0..<count).map { index in
            let start = margin + CGFloat(index) * (column + gap)
            return start...(start + column)
        }
        foldsBetween = false
    }
}
