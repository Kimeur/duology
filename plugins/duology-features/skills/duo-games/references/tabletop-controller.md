# Tabletop: the bottom half is the controller

When someone props iPhone Duo on a table, folded with the fold running side to side, the top region is easy to watch and the bottom region is a stable base for thumbs. Apple suggests media on top and controls below for this pose, with the same controls as in every other pose ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=283), [talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=263)). For a game, that makes a handheld console: the world above, the controls below.

Needs `FoldGeometry` ([fold-geometry.md](fold-geometry.md)). `GameScreen` in SKILL.md uses it.

## Code

```swift
import SwiftUI

// requires: FoldGeometry (references/fold-geometry.md)

/// Two views: the world first, the controls second.
/// Tabletop (an active fold running side to side): the world in the top region,
/// the controls in the bottom region, like a handheld console.
/// Every other pose: the world fills the view and the controls lie over it.
/// One layout in every pose, so neither view is rebuilt when the phone folds.
@available(iOS 27.1, *)
struct GameLayout: Layout {
    var fold: FoldGeometry

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let world = subviews[0]
        let controls = subviews[1]
        if fold.isActive, !fold.isVertical, let line = fold.frame {
            // Region frames are in this view's space; bounds can start anywhere.
            let top = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: line.minY)
            let bottom = CGRect(x: bounds.minX, y: bounds.minY + line.maxY,
                                width: bounds.width, height: bounds.height - line.maxY)
            world.place(at: top.origin, proposal: ProposedViewSize(top.size))
            controls.place(at: bottom.origin, proposal: ProposedViewSize(bottom.size))
        } else {
            world.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
            controls.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }
}
```

- One `Layout` places both views in every pose. Swapping a `VStack` for a `ZStack` with `if` changes the views' identity, so SwiftUI builds a new `SpriteView` for the scene.
- It splits only on an **active** fold that runs side to side. Flat and held tall, the phone isn't sitting on a table, so the world fills the display.
- The fold frame, margins included, belongs to neither region: no control lands in the 40 pt band.
- The world keeps `.ignoresSafeArea()`, so it reaches the top edge. The controls stay inside the safe area, above the Home indicator.

## What we measured

iPhone Duo simulator, iOS 27.1, 20 Oct 2026, `GameScreen` from SKILL.md.

| | Tabletop |
|---|---|
| Window | 669 × 951 pt |
| `GameLayout` bounds (safe area) | 669 × 917 pt (34 pt bottom inset) |
| Fold (`.division`, active) | 669 × 40 pt at y = 455.5 |
| Scene (world, top region) | 669 × 455.7 pt |
| Touch controls (bottom region) | 669 × 421.5 pt |
| Inner camera (`.occlusion`, inactive) | 37 × 58 pt at (611, 677.3): the right edge of the bottom region |
| Fire button | centred at (617, 865) in the window, 94 pt below the camera's frame |

- The camera region is inactive unless your game runs the inner camera. A game that does (a face-tracking game, a video chat) must keep controls out of its frame.
- Folding from book into tabletop is a rotation in Device Hub (Rotate Right). The scene went 951 × 669 → 669 × 455.7 pt in one step, and the same scene object kept running.
- Closing the phone from tabletop gave the scene a passing size of 466 × 455.7 pt for one pass (the new width with the old fold), then 466 × 678 pt. `didChangeSize(_:)` must cope with sizes that don't last.
- Without `GameLayout`, a full-window scene put the middle of its play area across the fold in tabletop (*measured* in the `GCVirtualController` probe).

## Book and the other poses

- **Book:** the world spans the fold, like the extended canvas pattern in `duo-patterns` (a map or a drawing that crosses the fold while its tools stay clear). The touch zones keep every control off it. Near the curve an image is harder to see ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=104)), so keep the score, text and small targets the player must hit precisely away from the fold (Duology's reading).
- **Open, flat:** nothing moves. The zones already leave the fold's frame free, so folding into book changes nothing under the thumbs.
- **Closed:** the controls lie over the world, inside the safe area, clear of the 84 pt trailing column.
- **Open, held tall and flat:** the overlay layout, as in book. Not measured with this game.

## Without the special layout

Tabletop is optional. Apple calls it a layout worth considering, not a requirement ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=276)). If you skip it, the game must still work there: the world fills the view and the controls lie over it. Check that no control lands in the fold band, and that the play area doesn't put the action across the fold.
