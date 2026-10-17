# Extended canvas

One big surface that uses the whole inner display, fold included: a map, a drawing board, a whiteboard, a timeline, a large table, a floor plan. The canvas runs across the fold. Its tools and dialogs never do.

Prior art: Microsoft's [extended canvas pattern](https://learn.microsoft.com/en-us/previous-versions/dual-screen/design/extended-canvas) for Surface Duo. Apple's matching rules: scrolling content does not need to avoid the fold, interactive elements do ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=568)).

## Use it when

- The content is one continuous space that people pan or zoom. More room means more of it on screen.
- Anything under the fold can be moved out of it with a drag.

Don't use it when the content has natural units (pages, items). Use [two-page](two-page.md) or [feed reflow](feed-reflow.md). Don't use it for two related views; that is a [dual view](dual-view.md).

## How it behaves

| State | Canvas | Tools and dialogs |
|---|---|---|
| Closed (outer display) | Fills the window | Bottom centre, or in the system toolbar |
| Open, flat | Fills the window, across the fold line | Bottom centre |
| Open, partly folded like a book | Still fills the window. People pan content out of the curve. | Move to the trailing region, same bottom edge |
| Partly folded across, set on a table like a laptop | Still fills the window | Move to the bottom region |

Sheets, alerts, menus, popovers and toolbar buttons move off the fold on their own ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=568), [HIG, Reserved regions](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions)). Only your own floating tools need code.

## Apple APIs

| Need | SwiftUI | UIKit |
|---|---|---|
| The surface | [`Canvas`](https://developer.apple.com/documentation/swiftui/canvas), [`Map`](https://developer.apple.com/documentation/mapkit/map), or your own view | `UIView`, `MKMapView`, `PKCanvasView` |
| Where the fold is | `FoldGeometry` (SKILL.md), built on [`reservedRegions(kind:options:layoutDirectionBehavior:)`](https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:)) | [`reservedRegions(kind:options:)`](https://developer.apple.com/documentation/uikit/uiview/reservedregions(kind:options:)) |
| Dialogs that avoid the fold | [`confirmationDialog`](https://developer.apple.com/documentation/swiftui/view/confirmationdialog(_:ispresented:titlevisibility:actions:)), `alert`, `sheet`, `toolbar` | `UIAlertController`, sheets, `UIBarButtonItem` |
| Artwork under the side bars | [`backgroundExtensionEffect()`](https://developer.apple.com/documentation/swiftui/view/backgroundextensioneffect()) (iOS 26) | [`UIBackgroundExtensionView`](https://developer.apple.com/documentation/uikit/uibackgroundextensionview) (iOS 26) |

Don't reach for an overlay `ArrangementView` here. Partly folded, an overlay arrangement puts its secondary view in the leading or top part of the display only ([hub](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)). Your canvas would shrink to one half, which defeats the pattern.

## Rules

1. Let the canvas fill the window and cross the fold. People pan it; nothing on it is stuck in the curve.
2. Move only the tools. Apple calls this displacement: keep the group together, move it the shortest way, and keep it close to where it was ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=146)).
3. Folded like a book, tools go to the trailing region. Set on a table and folded across, tools go to the bottom region and the canvas reads from the top ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=240)).
4. Use system dialogs and sheets. They avoid the fold for you. A custom popup centred on the window lands in the fold.
5. Keep tools inside the safe area. The canvas background may extend under the side bars; buttons may not ([talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)).
6. Keep the same tools in every state. Fewer tools when folded is a missing feature, not a layout.
7. Use the fold for layout through reserved regions. The hinge angle is for effects only ([talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/)).

## Recipe

Needs `FoldGeometry` from SKILL.md. Typechecks against the iOS 27.1 simulator SDK, also with an iOS 26 deployment target.

```swift
import SwiftUI

// requires: FoldGeometry (SKILL.md)

struct Stroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
}

@available(iOS 27.1, *)
struct SketchBoard: View {
    @State private var strokes: [Stroke] = []
    @State private var fold = FoldGeometry()
    @State private var confirmsClear = false

    var body: some View {
        GeometryReader { proxy in
            let tools = toolRegion(in: proxy.size)
            ZStack {
                // The canvas fills the whole view and runs across the fold.
                Canvas { context, _ in
                    for stroke in strokes {
                        var path = Path()
                        path.addLines(stroke.points)
                        context.stroke(path, with: .color(.primary), lineWidth: 3)
                    }
                }
                .contentShape(Rectangle())
                .gesture(drawGesture)
                .accessibilityLabel("Sketch board")

                // Tools are interactive, so they never sit on the fold.
                ToolPalette(onClear: { confirmsClear = true })
                    .frame(width: tools.width, height: tools.height, alignment: .bottom)
                    .position(x: tools.midX, y: tools.midY)
            }
        }
        .onFoldChange { fold = $0 }
        .animation(.smooth, value: fold)
        // System dialogs move off the fold on their own.
        .confirmationDialog("Clear the board?", isPresented: $confirmsClear) {
            Button("Clear", role: .destructive) { strokes.removeAll() }
        }
    }

    private var drawGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if value.translation == .zero {
                    strokes.append(Stroke(points: [value.location]))
                } else if !strokes.isEmpty {
                    strokes[strokes.count - 1].points.append(value.location)
                }
            }
    }

    /// The area the tools may use: the whole view when flat, one side of the fold when folded.
    private func toolRegion(in size: CGSize) -> CGRect {
        let whole = CGRect(origin: .zero, size: size)
        guard fold.isActive, let frame = fold.frame else { return whole }
        if fold.isVertical {
            return CGRect(x: frame.maxX, y: 0, width: size.width - frame.maxX, height: size.height)
        }
        return CGRect(x: 0, y: frame.maxY, width: size.width, height: size.height - frame.maxY)
    }
}

struct ToolPalette: View {
    var onClear: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Button("Pen", systemImage: "pencil.tip") {}
            Button("Eraser", systemImage: "eraser") {}
            Button("Clear", systemImage: "trash", action: onClear)
        }
        .labelStyle(.iconOnly)
        .padding()
        .background(.regularMaterial, in: Capsule())
        .padding(.bottom)
    }
}
```

Notes on the recipe:

- `fold.frame` includes the region's margins, so `frame.maxX` already leaves room for fingers next to the curve.
- The region frames are mirrored for right-to-left layouts by default, so `maxX` is the trailing side either way ([`ReservedRegion`](https://developer.apple.com/documentation/swiftui/reservedregion)).
- Every button has a title and a symbol, so VoiceOver reads the title even with `.iconOnly`.
- A real drawing app would add panning and zoom, so people can move a stroke out of the curve. With PencilKit, `PKCanvasView` gives you both.

## Pitfalls

- **A palette centred on the window.** Flat, bottom centre is fine. Partly folded, it sits right in the curve. That is the bug this pattern exists to fix.
- **Hiding tools when folded.** Move them; don't drop them.
- **Moving the canvas.** The canvas is the scrolling content. Apple says continuous content does not displace ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=146)).
- **Pinch and rotate.** Device Hub can't send two-finger touches in Xcode 27 ([Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)). Test zoom gestures on a device.
- **Driving layout from `onHingeChange`.** The hinge angle can update often and with varying precision (UIKit's `UIHinge.h` says so). Use reserved regions for layout.

## Test it

1. Open, flat: draw a line across the middle. It crosses the fold line with no gap.
2. Partially Open, held wide: the palette slides to the trailing region and keeps its bottom edge. The canvas does not move.
3. Partially Open, held tall (folded across): the palette sits in the bottom region.
4. Tap Clear while folded: the dialog appears on one side, not in the fold.
5. Close: the same three tools, on the outer display.

Not tested by Duology yet: the folded states. `simctl` has no pose command in Xcode 27.1, so run steps 2 to 4 by hand in Device Hub.

## Gallery screen

[`samples/DuologyGallery/DuologyGallery/Patterns/ExtendedCanvasView.swift`](../../../../../samples/DuologyGallery/DuologyGallery/Patterns/ExtendedCanvasView.swift)

## Sources

IDs point to [`reference/sources.md`](../../../../../reference/sources.md): D1 (hub), D2 (HIG), V1 (talk 111461), V3 (talk 111463), V4 (talk 111464), V6 (talk 111466), A12 (Xcode 27 release notes), P1b (Microsoft extended canvas).
