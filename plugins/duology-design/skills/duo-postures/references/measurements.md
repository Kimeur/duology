# Measurements by pose

What the iOS 27.1 iPhone Duo simulator reported in each pose, and what nobody has measured yet. Never hard-code these numbers: they are here to check screenshots and reason about layouts. Size from the view, pick layouts by size class, and read the fold from reserved regions.

## Where the numbers come from

| Source | Date | Poses | What it read |
|---|---|---|---|
| Probe in [device facts](https://github.com/Kimeur/duology/blob/main/reference/device-facts.md#how-we-measured) | 16 Oct 2026 | Open, flat, held wide | Window size, size classes, scale, hinge |
| `duo-patterns` probe ([two-page](https://github.com/Kimeur/duology/blob/main/plugins/duology-design/skills/duo-patterns/references/two-page.md#what-we-measured)) | 16 Oct 2026 | Open, flat, held wide | `.division` and `.occlusion`, default query and `.includeInactive` |
| Gallery app region overlay (`-showsRegions YES`), [screenshots](https://github.com/Kimeur/duology/tree/main/docs/assets/gallery) | 18 Oct 2026 | Closed, open, book, tabletop | Region frames and active state, the overlay view's size |
| This skill's probe | 18 Oct 2026 | Closed | Safe area, size classes, bar edge, regions, hinge; the recipes on screen |
| This skill's UIKit probe ([below](#uikit-probe)) | 19 Oct 2026 | Open wide, book, open tall, tabletop | When `layoutSubviews` runs, the `.division` region polled every frame, the hinge |

Device Hub set the poses: Closed, Open, Partially Open (book), and Partially Open then Rotate Right once (tabletop). On 19 Oct a script pressed the buttons through the Accessibility API. Xcode 27.1 (27A9275).

## Closed (outer display), portrait

*Measured* with this skill's probe, a view that fills the safe area:

- Window 466 × 678 pt (gallery overlay). Safe area 382 × 644 pt: 84 pt trailing, 34 pt bottom, 0 elsewhere.
- Size classes: compact width, regular height.
- `toolbarVerticalEdge`: `.trailing`, even on a screen with no toolbar.
- `.division`: none, with or without `.includeInactive`.
- `.occlusion`: two active regions, no margins. 37 × 37 pt at (400, 29): the outer camera (the gallery overlay, which truncates, printed 399). 84 × 174 pt at (382, 0): the status bar column. Both sit outside the safe area, so a view inside it gets frames past its own trailing edge.
- Hinge: `closed`, angle 0°.
- `TabletopPlayer`: video full screen, controls at the bottom centre of the safe area. `CountdownScreen`: the face in the top half, the buttons in the bottom half.
- An overlay `ArrangementView` put its primary (120 pt tall) at the top edge over the secondary. Views nested inside each half read `overlayArrangementZIndex` 1 for the primary and 0 for the secondary, and `splitArrangementAxis` `nil`.

## Open, flat, held wide (inner display)

- Window 951 × 669 pt, scale 3, regular width and regular height. Hinge `fullyOpen` at 180° (device facts probe).
- `.division`, default query: nothing. With `.includeInactive`: one inactive region, 40 × 669 pt at (455, 0), margins 20 pt each side ([two-page](https://github.com/Kimeur/duology/blob/main/plugins/duology-design/skills/duo-patterns/references/two-page.md#what-we-measured)).
- `.occlusion`, default query: one active region, 84 × 124 pt at the top trailing corner, where the status bar sits. With `.includeInactive`: also a 58 × 37 pt inactive region at (677, 21), the inner camera (our reading).
- The first layout pass returned no regions; the next one had them.

## Open, flat, held tall (inner display)

*Measured* with the UIKit probe after Open and Rotate Right once:

- View 669 × 951 pt.
- `.division` with `.includeInactive`: one inactive region, 669 × 40 pt at (0, 455). The same frame tabletop reports, so a `.split` layout lands in the same place flat and folded.
- Hinge `fullyOpen` at 180°.

## Book (Partially Open, held wide)

From the gallery overlay ([screenshot](https://github.com/Kimeur/duology/blob/main/docs/assets/gallery/regions-book.png)):

- `.division`: active, 40 × 669 pt at (455, 0). Same frame as flat; only `isActive` changed.
- `.occlusion`: inner camera inactive, 58 × 37 pt at (677, 21); status bar active, 84 × 124 pt at (867, 0).
- The system split view (the gallery's list-detail) evened out its columns at the fold.
- Hinge (UIKit probe): `partiallyOpen` from the first update, at 170°; settled at 127° about 0.7 s later. The region turned active at that moment, not when the status changed.
- The overlay prints y values 17 pt higher held wide, because its own view is 17 pt taller than the display (951 × 686 pt). The frames above subtract that. Why its view is taller, we don't know.

## Tabletop (Partially Open, then Rotate Right once)

From the gallery overlay ([screenshot](https://github.com/Kimeur/duology/blob/main/docs/assets/gallery/regions-tabletop.png)):

- Window 669 × 951 pt.
- `.division`: active, 669 × 40 pt at (0, 455). The top region is 455 pt tall, the bottom region 456 pt.
- `.occlusion`: inner camera inactive, 37 × 58 pt at (611, 677), on the right edge of the bottom region; status bar active, 144 × 82 pt at (525, 0).
- The system split view showed both columns, which suggests regular width. Size classes were not logged. (unverified)
- Hinge (UIKit probe): `partiallyOpen` at 172°, settled at 128° about 0.9 s later, when the region turned active.
- To return to the wide layout, press Rotate Right three more times.

## UIKit: layout passes on a fold

*Measured* with the [UIKit probe](#uikit-probe): four full-size sibling views, one display link polling the region every frame, and a hinge logger.

| View | Partially Open (book and tabletop) | Open again |
|---|---|---|
| Reads regions in `layoutSubviews`, no hinge code | One pass, in the frame the region turned active; it read `active` | One pass when the region turned inactive |
| Same, plus `setNeedsLayout` on a hinge status change | A pass on the status change that read `inactive`, then the same automatic pass | One pass: status and region changed together |
| Same, plus `setNeedsLayout` on every hinge update | A pass per update (20 to 330 ms apart): 3 (book) or 13 (tabletop) that read `inactive`, one that read `active` with the automatic pass, then 8 more | A pass per update, 13 to 14 |
| Never reads regions | No pass | No pass |

- The polled region changed in the same frame as the automatic pass. On Partially Open the status had changed 0.7 to 0.9 s earlier. On Open the status turned `fullyOpen` (180°) in the same frame as the region turned inactive.
- At launch, the same view got a second pass when the region first appeared (the first pass read none).
- Our reading: UIKit tracks the region query made in `layoutSubviews` and invalidates that view when the answer changes, as it does for traits. The headers don't say so.

## Not yet measured

| Gap | Why it matters | How to fill it |
|---|---|---|
| Size classes in book and tabletop | Rule 2 assumes regular width on the inner display in every inner pose | Run the [pose probe](#probe-to-re-measure) in each pose |
| Hinge angle while Option-dragging the slider | Effects scale with the angle | Same probe; then Option-drag the slider |
| Fold width at other angles | Whether the 40 pt frame changes as the phone closes | Option-drag the slider and log `.division` |
| Tent and flipped | Our reading says the outer display; Device Hub can't set either | A real iPhone Duo |
| `FoldRegionsLayout` and `FoldRegionsView` folded | Both recipes rely on them | Run the recipes in book and tabletop |
| Whether `viewDidLayoutSubviews` gets the same extra pass | A view controller that reads regions there may miss a fold | Log it in the UIKit probe below |
| Right-to-left | Content should stay leading | Run with the Right-to-Left Pseudolanguage |

## Probe to re-measure

Attach it to a screen's root, press each pose in Device Hub, and read the console. It typechecks against the iOS 27.1 simulator SDK.

```swift
import SwiftUI

/// Logs size, size classes, the fold and the hinge every time they change.
@available(iOS 27.1, *)
struct PoseProbe: ViewModifier {
    @Environment(\.horizontalSizeClass) private var width
    @Environment(\.verticalSizeClass) private var height

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: String.self) { proxy in
                let folds = proxy.reservedRegions(kind: .division, options: .includeInactive)
                    .map { "\($0.isActive ? "active" : "inactive") \($0.frame)" }
                return "size \(proxy.size), folds \(folds)"
            } action: { line in
                print("POSE", line, "width \(String(describing: width)) height \(String(describing: height))")
            }
            .onHingeChange { _, context in
                if let hinge = context.hinge {
                    print("POSE hinge", hinge.status, Int(hinge.angle.degrees))
                } else {
                    print("POSE hinge nil")
                }
            }
    }
}
```

Use it as `.modifier(PoseProbe())`. Size class changes alone don't print a line; the geometry usually changes with them.

## UIKit probe

Logs every layout pass with the fold it read, and the hinge. Make it a view controller's `view`, press Partially Open and Open in Device Hub, and read the console. To test `viewDidLayoutSubviews`, log the same line there. It typechecks against the iOS 27.1 simulator SDK.

```swift
import UIKit

/// Logs each layout pass with the fold it read, and each hinge update.
@available(iOS 27.1, *)
final class FoldLayoutProbe: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        addInteraction(UIHingeInteraction { _, update in
            guard let hinge = update.hinge else {
                print("PROBE hinge nil")
                return
            }
            print("PROBE hinge", hinge.status.rawValue, Int(hinge.angle * 180 / .pi))
        })
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let folds = reservedRegions(kind: .division, options: .includeInactive)
            .map { "\($0.isActive ? "active" : "inactive") \($0.frame)" }
        print("PROBE layout", CACurrentMediaTime(), bounds.size, folds)
    }
}
```

`UIHinge.Status` raw values: 1 closed, 2 partially open, 3 fully open. Our run used four sibling views (no hinge code, a nudge on status change, a nudge on every update, no region query) and a display link that polled the region each frame.
