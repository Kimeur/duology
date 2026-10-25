import CoreGraphics
import Foundation

/// Big answer buttons in the space the answers pane has: as large as they can be, in a
/// tidy grid (one row, one column, or two by two for four answers).
///
/// It tries every column count that fills its rows evenly and keeps the one whose buttons'
/// shorter side is longest. Pure geometry, tested on the Mac.
nonisolated struct AnswerGrid: Equatable, Sendable {
    /// Our choice, not Apple's: twice the 44 pt minimum touch target Apple asks for, because
    /// small fingers are less precise. Every pose of the sample keeps the buttons above it.
    static let minimumTarget: CGFloat = 88
    /// Buttons stop growing here, so one or two answers don't become a wall.
    static let largestButton = CGSize(width: 360, height: 220)

    let columns: Int
    let rows: Int
    /// Every button's size.
    let button: CGSize
    /// Each button's frame, in the grid's own space, centred in it.
    let frames: [CGRect]
    let spacing: CGFloat

    var meetsMinimum: Bool {
        !frames.isEmpty && min(button.width, button.height) >= Self.minimumTarget
    }

    init(count: Int, in size: CGSize, spacing: CGFloat = 16, largest: CGSize = AnswerGrid.largestButton) {
        self.spacing = spacing
        var best: (columns: Int, rows: Int, button: CGSize)?
        for columns in 1...max(count, 1) where count > 0 && count % columns == 0 {
            let rows = count / columns
            let width = (size.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
            let height = (size.height - CGFloat(rows - 1) * spacing) / CGFloat(rows)
            guard width > 0, height > 0 else { continue }
            let button = CGSize(width: min(width, largest.width), height: min(height, largest.height))
            if let current = best, min(button.width, button.height) <= min(current.button.width, current.button.height) {
                continue
            }
            best = (columns, rows, button)
        }
        guard let best else {
            columns = 0
            rows = 0
            button = .zero
            frames = []
            return
        }
        columns = best.columns
        rows = best.rows
        button = best.button
        let gridWidth = CGFloat(columns) * button.width + CGFloat(columns - 1) * spacing
        let gridHeight = CGFloat(rows) * button.height + CGFloat(rows - 1) * spacing
        let origin = CGPoint(x: (size.width - gridWidth) / 2, y: (size.height - gridHeight) / 2)
        frames = (0..<count).map { index in
            CGRect(x: origin.x + CGFloat(index % best.columns) * (best.button.width + spacing),
                   y: origin.y + CGFloat(index / best.columns) * (best.button.height + spacing),
                   width: best.button.width, height: best.button.height)
        }
    }
}
