# Split and seating

How `SharedSplit` places and turns the two halves, where the seam falls for each person, and how to put the seam on the fold. The types come from [SKILL.md](../SKILL.md).

*Measured* means we ran it in a probe app with UI tests on the iPhone Duo simulator (Xcode 27.1, iOS 27.1, a cloned simulator that started closed). *Derived* means arithmetic on measured or Apple numbers. *Unverified* means we could not confirm it.

## What SharedSplit does

The axis follows the view's own shape, like `EvenSplit` in `duo-layout`. Seating only decides the turns.

| Split | Seat | Where | `.sameWay` | `.faceToFace` |
|---|---|---|---|---|
| Stacked (taller than wide) | first | top | 0 | 2 quarter turns: upside down |
| Stacked | second | bottom | 0 | 0 |
| Side by side | first | left | 0 | 1 quarter turn: top edge to the right |
| Side by side | second | right | 0 | 3 quarter turns: top edge to the left |

Face to face, every half's top edge lies on the seam. Each person sits at the far edge of their own half and reads it the right way up.

*Measured* on the cloned simulator (closed, portrait, 466 × 678 pt window):

| Case | Each half | What we saw |
|---|---|---|
| Stacked, same way | 382 × 321 pt, 2 pt gap | both halves upright |
| Stacked, face to face | 382 × 321 pt | top half upside down, its top edge on the seam; taps and drags worked |
| Side by side, face to face (a 382 × 220 pt frame we forced, because the clone did not rotate) | 190 × 220 pt slot, content laid out at 220 × 190 pt | each half turned a quarter toward the seam; taps worked |
| Side by side, right-to-left | 190 × 220 pt | first seat still on the left; text in each half ran right to left |

Why the split pins left-to-right for placement: an `HStack` follows the layout direction, so in a right-to-left language the first seat would land on the right. Its quarter turn would then point its top edge away from the seam. `SharedSplit` places the seats left to right and passes the real direction into each half, so the content still reads right to left.

## Where the seam is

The seam is where both people's hands meet. Keep each seat's own controls, and above all its destructive controls, at the edge farthest from it.

| Split | Seating | First seat's edge on the seam | Second seat's edge on the seam |
|---|---|---|---|
| Stacked | same way | bottom | top |
| Stacked | face to face | top | top |
| Side by side | same way | right side of the screen | left side of the screen |
| Side by side | face to face | top | top |

The bottom of the second seat's half is away from the seam in every row. That is why the play screen in SKILL.md puts Leave there. For any seat:

```swift
import SwiftUI

extension Facing {
    /// Where a seat's own controls go: away from the seam.
    func controlsAlignment(for seat: Seat, sideBySide: Bool) -> Alignment {
        self == .sameWay && seat == .first && !sideBySide ? .top : .bottom
    }
}
```

The halves themselves don't know the split axis. Read it once where you build the split, for example with `onGeometryChange(for:of:action:)` ([doc](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:))), and pass it down.

## Let people choose the seating

No API reports how people sit around the phone. The hinge reports status and angle only, and Apple tells you to use it for effects, not layout ([api-index](../../../../../reference/api-index.md#hinge)). Ask on the setup screen, upright, before play:

```swift
import SwiftUI

struct SeatingPicker: View {
    @AppStorage("seating") private var facing: Facing = .sameWay
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Picker("Seating", selection: Binding(
            get: { facing },
            set: { new in
                if reduceMotion {
                    facing = new
                } else {
                    withAnimation(.snappy) { facing = new }
                }
            }
        )) {
            Text("Side by side").tag(Facing.sameWay)
            Text("Face to face").tag(Facing.faceToFace)
        }
        .pickerStyle(.segmented)
    }
}
```

- Save the choice. People who play face to face once will do it again.
- Changing the seating mid-session should keep each half's state: `turned(_:)` stays the same modifier with a new number, so SwiftUI keeps the views. We measured state surviving an axis flip for `EvenSplit` in `duo-layout`; we did not measure a seating change. (unverified)
- Don't guess the seating from the hinge or from device orientation. A phone flat on a table and a phone held open both report fully open.

## Shared use in each pose

| Pose | Halves | Notes |
|---|---|---|
| Closed, portrait | stacked, 382 × 321 pt each inside the safe area (*measured*) | small: drop labels before you shrink touch targets (`duo-layout` thresholds) |
| Closed, held sideways | side by side | `ArrangementView` would show only one half here (*measured* in `duo-layout`) |
| Open, flat, wide | side by side, about 474 pt wide each in a 951 pt window (*derived*; less inside the safe area) | the natural face-to-face pose |
| Open, tall | stacked | face to face works the same way |
| Partly folded | seam on the fold, see below | keep controls out of the fold's frame |
| Split View | your app has half the inner display; both people share that half | shared play is cramped here; test it, but design for full screen |

Folded like a tent ("set the phone down like a tent", [talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=215)), our reading is that only the outer display faces out, so only one side of the table sees a screen. Not a shared pose. (unverified)

## Seam on the fold

`SharedSplit` puts its seam in the middle of its own frame. Partly folded, that matches the fold only if the split is centred on the display. When it must match, use `FoldSplitLayout` from `duo-layout` ([custom-split.md](../../../../duology/skills/duo-layout/references/custom-split.md#put-the-seam-on-the-fold)) and turn each half yourself:

```swift
import SwiftUI

/// The split's axis and the active fold's frame, read from the split's own geometry.
/// `nonisolated`: onGeometryChange needs a conformance that isn't tied to the main actor.
@available(iOS 27.1, *)
nonisolated struct SplitShape: Equatable, Sendable {
    var sideBySide = true
    var fold: CGRect?

    init() {}

    init(_ proxy: GeometryProxy) {
        sideBySide = proxy.size.width >= proxy.size.height
        // Unmirrored frames, to match the left-to-right placement of the seats.
        fold = proxy.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed)
            .first(where: \.isActive)?.frame
    }
}

/// SharedSplit for a partly folded phone: the seam sits on the active fold.
/// Needs FoldSplitLayout from duo-layout.
@available(iOS 27.1, *)
struct FoldedSharedSplit<First: View, Second: View>: View {
    var facing: Facing = .sameWay
    @ViewBuilder var first: () -> First
    @ViewBuilder var second: () -> Second
    @Environment(\.layoutDirection) private var direction
    @State private var shape = SplitShape()

    var body: some View {
        FoldSplitLayout(fold: shape.fold, spacing: 2) {
            first()
                .environment(\.layoutDirection, direction)
                .turned(facing.quarterTurns(for: .first, sideBySide: shape.sideBySide))
            second()
                .environment(\.layoutDirection, direction)
                .turned(facing.quarterTurns(for: .second, sideBySide: shape.sideBySide))
        }
        .environment(\.layoutDirection, .leftToRight)
        .onGeometryChange(for: SplitShape.self, of: SplitShape.init) { new in
            shape = new
        }
    }
}
```

- `FoldSplitLayout` decides side by side or stacked from its bounds the same way, so the turns match its placement.
- The fold's frame includes margins for interactive content, and `FoldSplitLayout` uses the whole frame as the gap ([ReservedRegion](https://developer.apple.com/documentation/swiftui/reservedregion)).
- We could not fold the simulator from a script; `simctl` has no pose command. Not run while partly folded. (unverified)

## Small halves

- Lay out each half by its own size. An `EvenSplit` half keeps the window's size classes (*measured* in `duo-layout`), so size classes don't tell you a half is small.
- Closed, a half is about the size of a small landscape phone screen: 382 × 321 pt here. Test the largest Dynamic Type sizes there.
- Keep touch targets at 44 pt or more in every half. Drop labels and spacing first.
