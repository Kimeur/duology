import SwiftUI

// Converts between SwiftUI's geometry and the engine's. `nonisolated` because
// onGeometryChange runs its transform closure off the main actor.

nonisolated extension GameRect {
    init(_ rect: CGRect) {
        self.init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
    }
}

nonisolated extension GamePoint {
    init(_ point: CGPoint) {
        self.init(x: point.x, y: point.y)
    }
}

nonisolated extension CGPoint {
    init(_ point: GamePoint) {
        self.init(x: point.x, y: point.y)
    }
}

nonisolated enum FoldAvoidance {
    /// The play area for one half: its bounds minus a margin, clear of the fold and
    /// the cameras. Reads reserved regions, which exist from iOS 27.1; earlier systems
    /// (and phones that don't fold) report none, so the whole half is used.
    static func playArea(in proxy: GeometryProxy, margin: Double) -> GameRect {
        let bounds = GameRect(CGRect(origin: .zero, size: proxy.size))
        return PlayArea.fit(bounds, avoiding: reservedFrames(in: proxy), margin: margin)
    }

    /// Active division (fold) and occlusion (camera) regions, in the proxy's own coordinates.
    static func reservedFrames(in proxy: GeometryProxy) -> [GameRect] {
        guard #available(iOS 27.1, *) else { return [] }
        return [ReservedRegion.Kind.division, .occlusion].flatMap { kind in
            proxy.reservedRegions(kind: kind)
                .filter(\.isActive)
                .map { GameRect($0.frame) }
        }
    }
}
