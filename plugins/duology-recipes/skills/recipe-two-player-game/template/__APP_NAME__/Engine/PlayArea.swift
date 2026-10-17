import Foundation

/// Where targets may appear inside one player's half.
///
/// The view passes its own bounds and the frames it must keep clear: on iPhone Duo,
/// the fold when the phone is partly open and a front camera (SwiftUI reports both as
/// reserved regions). Plain geometry, so it is tested on the Mac with sizes from every pose.
nonisolated enum PlayArea {
    /// `bounds` inset by `margin`, then cut away from every rect in `avoid`.
    ///
    /// For each rect in the way, it tries the strips to its left, right, above and below,
    /// and keeps the strip whose shorter side is longest, so targets keep their size.
    static func fit(_ bounds: GameRect, avoiding avoid: [GameRect], margin: Double) -> GameRect {
        var area = bounds.insetBy(dx: margin, dy: margin)
        guard !area.isEmpty else { return .zero }
        for blocked in avoid where !blocked.isEmpty {
            let keepClear = blocked.insetBy(dx: -margin, dy: -margin)
            guard keepClear.intersects(area) else { continue }
            let strips = [
                GameRect(x: area.minX, y: area.minY, width: keepClear.minX - area.minX, height: area.height),
                GameRect(x: keepClear.maxX, y: area.minY, width: area.maxX - keepClear.maxX, height: area.height),
                GameRect(x: area.minX, y: area.minY, width: area.width, height: keepClear.minY - area.minY),
                GameRect(x: area.minX, y: keepClear.maxY, width: area.width, height: area.maxY - keepClear.maxY),
            ].filter { $0.width > 0 && $0.height > 0 }
            guard let best = strips.max(by: { $0.shortSide < $1.shortSide }) else {
                return .zero
            }
            area = best
        }
        return area
    }
}
