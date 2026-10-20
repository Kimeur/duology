import SwiftUI

extension DuoColumns {
    /// Items for `LazyVGrid`: each column's fixed width, and the real gap after it, so the gap
    /// at the fold can be wider than the others. Same helper as duo-design-system's grid.
    /// Before the first layout pass (zero width) it falls back to flexible columns.
    var gridItems: [GridItem] {
        guard let first = columns.first, first.width > 0 else {
            return Array(repeating: GridItem(.flexible()), count: max(1, columns.count))
        }
        return columns.indices.map { index in
            let next = index + 1 < columns.count ? columns[index + 1].x : columns[index].maxX
            return GridItem(.fixed(columns[index].width), spacing: next - columns[index].maxX, alignment: .top)
        }
    }
}
