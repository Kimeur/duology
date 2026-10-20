# Touch controls on iPhone Duo

The controls from SKILL.md: a stick that appears where the thumb lands in the movement zone, and a fire button in the action zone. Needs `FoldGeometry` ([fold-geometry.md](fold-geometry.md)), `TouchZones` and `GameInput` (SKILL.md). Then Apple's two ready-made controllers, `GCVirtualController` and Touch Controller, and where they land on iPhone Duo.

## Why zones, and why the fold sits between them

- Players expect movement on the left side and the camera or actions on the right. Apple suggests a stick that appears wherever the thumb lands, and the biggest input areas you can give ([HIG: Game controls](https://developer.apple.com/design/human-interface-guidelines/game-controls#Touch-controls)).
- On the open inner display held wide, the natural line between those two areas is the fold. Folding into book turns that line into a curve where taps are hard ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=568)).
- `TouchZones` gives the fold's whole frame, 40 pt with its margins (*measured*), to neither zone. It reads the frame with `.includeInactive`, so the zones are the same flat and folded: folding mid-game moves nothing under the thumbs.
- A stick dragged from the movement zone may pass over the fold. It keeps working: the drag started outside it (*measured* by UI test: a drag from x = 445 to 545 pt in book).

## Code

```swift
import SwiftUI

// requires: FoldGeometry (references/fold-geometry.md), GameInput (SKILL.md)

/// A stick that appears where the thumb lands in the movement zone, and a fire
/// button in the bottom corner of the action zone. Lay it out inside the safe area.
@available(iOS 27.1, *)
struct TouchControls: View {
    let input: GameInput
    @State private var fold = FoldGeometry()   // read here: this view's own space
    @State private var stick: Stick?

    private struct Stick: Equatable { var origin: CGPoint; var thumb: CGPoint }
    private let reach: CGFloat = 56

    var body: some View {
        GeometryReader { proxy in
            let zones = TouchZones(size: proxy.size, fold: fold)
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: zones.move.width, height: zones.move.height)
                    .offset(x: zones.move.minX, y: zones.move.minY)
                    .gesture(moveGesture)
                if let stick {
                    Circle().stroke(.white.opacity(0.6), lineWidth: 2)
                        .frame(width: reach * 2, height: reach * 2)
                        .position(stick.origin)
                        .allowsHitTesting(false)
                    Circle().fill(.white.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .position(stick.thumb)
                        .allowsHitTesting(false)
                }
                PressButton(systemImage: "bolt.fill", label: "Fire") { input.isFiring = $0 }
                    .position(x: zones.act.maxX - 52, y: zones.act.maxY - 52)
            }
            .coordinateSpace(.named("controls"))
        }
        .onFoldChange { fold = $0 }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("controls"))
            .onChanged { drag in
                let origin = stick?.origin ?? drag.startLocation
                let dx = drag.location.x - origin.x
                let dy = drag.location.y - origin.y
                let scale = min(1, reach / max(hypot(dx, dy), 1))
                stick = Stick(origin: origin, thumb: CGPoint(x: origin.x + dx * scale, y: origin.y + dy * scale))
                input.move = CGVector(dx: dx * scale / reach, dy: -dy * scale / reach)
            }
            .onEnded { _ in
                stick = nil
                input.move = .zero
            }
    }
}

/// Reports touch down and touch up, as a game button needs. 72 pt, above the 44 pt minimum.
struct PressButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    let onPress: @MainActor (Bool) -> Void
    @State private var isPressed = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.title)
            .foregroundStyle(.white)
            .frame(width: 72, height: 72)
            .background(Circle().fill(.white.opacity(isPressed ? 0.45 : 0.2)))
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        onPress(true)
                    }
                    .onEnded { _ in
                        isPressed = false
                        onPress(false)
                    }
            )
            .sensoryFeedback(.impact, trigger: isPressed) { _, pressed in pressed }
            .accessibilityElement()
            .accessibilityLabel(Text(label))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                onPress(true)
                onPress(false)
            }
    }
}
```

- The movement zone is a clear layer with its own `contentShape`, beside the button, not around it. The button keeps its own frame and accessibility element. (`recipe-two-player-game` measured a gesture and content shape on a container taking over a target's accessibility frame.)
- `DragGesture(minimumDistance: 0)` gives touch down and touch up, which a game button needs (hold to fire). A `Button` only reports the end of a tap.
- `GameInput.move.dy` is positive up, like SpriteKit; SwiftUI's `y` grows down, hence the minus.
- Pressed state, a haptic and a symbol that says what the button does: Apple's three rules for virtual buttons ([HIG: Game controls](https://developer.apple.com/design/human-interface-guidelines/game-controls#Touch-controls)). The haptic shakes the whole phone; offer a switch.
- VoiceOver: the button is a labelled button with a default action. Movement needs a game-specific alternative (for example, tap to move toward a point).

## What we measured

iPhone Duo simulator, iOS 27.1, 20 Oct 2026. Positions from the probe logs and screenshots; touches from UI tests (below).

| Pose | Control area | Movement zone | Action zone | Fire button centre |
|---|---|---|---|---|
| Closed | 382 × 644 pt | 0 to 191 pt | 191 to 382 pt | (330, 592) |
| Book | 951 × 635 pt | 0 to 455.5 pt | 495.5 to 951 pt | (899, 583) |
| Tabletop (bottom region) | 669 × 421.5 pt | 0 to 334.5 pt | 334.5 to 669 pt | (617, 369.5) |

- The fire button centres come from the zones (52 pt in from the action zone's bottom trailing corner). The screenshots and the UI tests' element frames put the button at those points, within a point (tabletop: (617, 865) in the window).
- *Measured:* on the first layout pass the fold was not reported yet, so the zones split at the middle (475.5 pt held wide) for one pass, then moved to the fold.
- *Measured* by UI test in book: a drag that started at x = 445 pt moved the stick; one that started at the fold's centre (475.5 pt) or at 505 pt did nothing. Fire worked in closed, book and tabletop, and a drag in the movement zone moved the stick in all three ([measurements.md](measurements.md#touch-by-ui-test)).

## Apple's ready-made controllers

### GCVirtualController

`GCVirtualController` (iOS 15) draws a system controller over your game from a list of elements, and feeds a `GCController` like a real one ([doc](https://developer.apple.com/documentation/gamecontroller/gcvirtualcontroller)). It knows nothing about the fold.

- *Measured* in book (951 × 669 pt): the stick sat bottom left and the A and B buttons bottom right, far from the fold.
- *Measured* closed (portrait) and in tabletop: A and B drew near the bottom, below the fold in tabletop. The stick didn't show in either screenshot (unverified why; it showed in book).
- *Measured:* its controller reported the product category "Touch Controller" and the vendor name "Apple Touch Controller".
- To place the controls yourself, set `isHidden` on its configuration (iOS 17) and feed your own controls into it with `setValue(_:forButtonElement:)` and `setPosition(_:forDirectionPadElement:)` ([doc](https://developer.apple.com/documentation/gamecontroller/gcvirtualcontroller/configuration/ishidden)). Then lay them out with `TouchZones`.

### Touch Controller

The Touch Controller framework (iOS 26) draws controls with Metal, inside your own render pass, and exposes them as a `GCController` ([doc](https://developer.apple.com/documentation/touchcontroller)). Each control sits at an anchor (corners, edge centres or the centre) plus an offset, relative to the size you give it ([`TCControlLayout`](https://developer.apple.com/documentation/touchcontroller/tccontrollayout)).

- *Measured:* `TCTouchController.isSupported` was `false` on the iPhone Duo simulator. Creating one where it isn't supported is a fatal error ([doc](https://developer.apple.com/documentation/touchcontroller/tctouchcontroller/issupported)). Check `isSupported` first, fall back to `TouchControls`, and test Touch Controller on a device.
- *Derived from the header:* the centre, top centre and bottom centre anchors sit on a top-to-bottom fold, and the left and right centre anchors sit on a side-to-side fold in tabletop. Use the corner anchors on the inner display, or give it the size of one region. (unverified on a device)
- Set `size` and `drawableSize` again on every fold, in `mtkView(_:drawableSizeWillChange:)`. Code: [scene-and-renderer.md](scene-and-renderer.md#touch-controller).
