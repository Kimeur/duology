# FoldGeometry: where the fold crosses a view

`TouchControls`, `TouchZones`, `GameLayout` and `GameScreen` read the fold with `FoldGeometry` and `onFoldChange(_:)`. It is the same helper as in `duo-postures` ([fold-regions.md](https://github.com/Kimeur/duology/blob/main/plugins/duology-design/skills/duo-postures/references/fold-regions.md)) and `duo-reading`. Keep one copy per app. If the app already has one, check that its `init(_:)` filters with `liesInside(_:of:)`.

- It asks for inactive regions too (`.includeInactive`), so a flat inner display still reports where its fold is, and touch zones don't move when the phone folds. The default query returned only active regions on the iPhone Duo simulator (*measured* in `duo-layout`).
- It drops a fold that doesn't split the view in two. The tabletop control area, which sits below the fold, then reads as "no fold", which is what you want.
- Keep `nonisolated`. A new Xcode 27.1 app makes types main-actor isolated by default, and `onGeometryChange` then rejects the `Equatable` conformance.
- Frames come back in the view's own coordinate space, mirrored for right-to-left by default ([`ReservedRegion`](https://developer.apple.com/documentation/swiftui/reservedregion)).

```swift
import SwiftUI

/// Where the fold crosses a view, read from the view's reserved regions.
/// Layout input only. Never drive layout from the hinge angle.
@available(iOS 27.1, *)
nonisolated struct FoldGeometry: Equatable, Sendable {
    /// The fold's frame in this view's space, margins included. Nil when no fold
    /// splits the view in two, including a fold that lies outside it or only touches an edge.
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

    init(_ proxy: GeometryProxy) {
        // The default query returns active regions only. Ask for inactive ones too,
        // so a flat inner display still tells you where its fold is.
        // Keep only a fold with part of this view on each side of it.
        let size = proxy.size
        let folds = proxy.reservedRegions(kind: .division, options: .includeInactive)
            .filter { Self.liesInside($0.frame, of: size) }
        if let fold = folds.first(where: \.isActive) ?? folds.first {
            frame = fold.frame
            isActive = fold.isActive
        }
    }

    /// True when a fold frame splits a view of `size` into two non-empty parts:
    /// view left and right of a top to bottom fold, or above and below a side to side one.
    static func liesInside(_ frame: CGRect, of size: CGSize) -> Bool {
        if frame.height > frame.width {
            return frame.minX > 0 && frame.maxX < size.width
        }
        return frame.minY > 0 && frame.maxY < size.height
    }
}

@available(iOS 27.1, *)
extension View {
    /// Calls `action` with the fold geometry now and every time it changes.
    func onFoldChange(_ action: @escaping (FoldGeometry) -> Void) -> some View {
        onGeometryChange(for: FoldGeometry.self) { proxy in
            FoldGeometry(proxy)
        } action: { fold in
            action(fold)
        }
    }
}
```

## What the game's views see

*Measured* in the probe for this skill (iOS 27.1 simulator, 20 Oct 2026). `GameScreen` reads the fold in the safe-area layout; `TouchControls` reads it in its own view.

| Pose | View | Size | `frame` | `isActive` |
|---|---|---|---|---|
| Closed | `GameScreen` | 382 × 644 pt | `nil` | `false` |
| Open, flat, held wide | `GameScreen` | 951 × 635 pt | 40 × 669 pt at (455.5, 0) | `false` |
| Book | `GameScreen` and `TouchControls` | 951 × 635 pt | 40 × 669 pt at (455.5, 0) | `true` |
| Tabletop | `GameScreen` | 669 × 917 pt | 669 × 40 pt at (0, 455.5) | `true` |
| Tabletop | `TouchControls`, below the fold | 669 × 421.5 pt | `nil`: the fold lies above the view | `false` |

- The fold frame is taller than the view held wide (669 pt against 635 pt): it runs under the bottom inset. Use `minX` and `maxX` for a vertical fold; ignore its `y` and `height`.
- During the rotation out of tabletop, `TouchControls` read the fold at y = −495.5 for one pass, then at y = 0. Values in between poses are not final: never cache them.
