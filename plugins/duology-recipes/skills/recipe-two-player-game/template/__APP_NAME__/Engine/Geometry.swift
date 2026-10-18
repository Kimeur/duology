import Foundation

// Tiny geometry types for the engine. CGRect's members come from CoreGraphics,
// so the engine keeps its own and stays Foundation only. The app converts at the
// edge (Duel/GeometryBridge.swift).

nonisolated struct GamePoint: Equatable, Sendable {
    var x: Double
    var y: Double

    static let zero = GamePoint(x: 0, y: 0)

    func distance(to other: GamePoint) -> Double {
        hypot(other.x - x, other.y - y)
    }
}

nonisolated struct GameRect: Equatable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let zero = GameRect(x: 0, y: 0, width: 0, height: 0)

    var minX: Double { x }
    var minY: Double { y }
    var maxX: Double { x + width }
    var maxY: Double { y + height }
    var midX: Double { x + width / 2 }
    var midY: Double { y + height / 2 }
    var shortSide: Double { min(width, height) }
    var isEmpty: Bool { width <= 0 || height <= 0 }

    /// Shrinks each side by `dx` and `dy` (grows for negative values). Never below zero size.
    func insetBy(dx: Double, dy: Double) -> GameRect {
        GameRect(x: x + dx, y: y + dy, width: max(0, width - 2 * dx), height: max(0, height - 2 * dy))
    }

    func intersects(_ other: GameRect) -> Bool {
        !isEmpty && !other.isEmpty
            && minX < other.maxX && other.minX < maxX
            && minY < other.maxY && other.minY < maxY
    }

    func contains(_ point: GamePoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }

    func contains(_ other: GameRect) -> Bool {
        other.minX >= minX && other.maxX <= maxX && other.minY >= minY && other.maxY <= maxY
    }
}
