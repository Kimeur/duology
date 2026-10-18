---
name: duo-transitions
description: "Makes fold, unfold, partial fold and rotation on iPhone Duo, Apple's foldable, feel like one app instead of a reload. Use when a screen flashes, blinks, jumps, reloads, pops or moves its controls as the phone opens or closes, or when writing or reviewing SwiftUI or UIKit code that animates a resize: AnyLayout, stable ForEach IDs, matchedGeometryEffect, geometryGroup, .animation(_:value:), transaction, withAnimation, contentTransition, accessibilityReduceMotion, viewWillTransition(to:with:), animate(alongsideTransition:completion:), UIView.animate with a SwiftUI spring, and 120 Hz ProMotion frame budgets."
metadata:
  verified: "Xcode 27.1 (27A9275), iOS 27.1 simulator, device: no"
  sources: "https://github.com/Kimeur/duology/blob/main/reference/sources.md"
---

# duo-transitions

Opening or closing iPhone Duo resizes your app, the same way a person resizes it in iPhone Mirroring ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=142)). People do it often, so Apple asks for an app that stays predictable and feels like one experience at every size ([Tech Talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=483)). This skill makes the change read as the same screen taking a new shape, not a new screen loading.

Load other skills for neighbouring work: `duo-continuity` (scroll, selection, typing and playback that must survive), `duo-patterns` (layouts, and displacement off the fold), `duo-layout` (size classes, reserved regions), `duo-navigation` (bars move on their own).

Labels: *measured* means we ran it on the iPhone Duo simulator (iOS 27.1); see [references/evidence.md](references/evidence.md). *Unverified* means we could not confirm it. *Device only* means the simulator can't show it. Everything else comes from Apple's pages, linked inline. Full source list: [reference/sources.md](https://github.com/Kimeur/duology/blob/main/reference/sources.md).

## What each change hands your app

MEASURED-TABLE

## How SwiftUI animates a resize

1. Every update runs in a transaction. When an animatable value changes (a frame, an offset, an opacity), SwiftUI looks for an animation in that transaction. With one, it interpolates. Without one, the value jumps ([WWDC23 Explore SwiftUI animation](https://developer.apple.com/videos/play/wwdc2023/10156/?time=280)).
2. `withAnimation` puts an animation in the transaction of a state change *you* make. A fold is not your state change. The system resizes the window, SwiftUI lays out again and updates `horizontalSizeClass`. None of your code runs first, so there is nothing to wrap.
3. So read the size class, or the view's size, in `body` and build the layout from it. The new layout then lands in the same update as the new size.
4. Opt in with [`animation(_:value:)`](https://developer.apple.com/documentation/swiftui/view/animation(_:value:)). When `value` changes in an update, the views below the modifier animate in that update. Key it on a discrete value: the width class, a column count, the fold's active state. Never key it on the raw size, which changes many times during a Split View drag.
5. Opt out below an animation: `.animation(nil, value:)` for a subtree, [`transaction(_:)`](https://developer.apple.com/documentation/swiftui/view/transaction(_:)) with `$0.animation = nil` for one leaf (Apple says use it on leaf views), and [`contentTransition(.identity)`](https://developer.apple.com/documentation/swiftui/contenttransition/identity) to stop a text or symbol cross-fade while its frame still moves.
6. Frames animate at the leaf views. An opt-out on a container also stops that container's frame. [`geometryGroup()`](https://developer.apple.com/documentation/swiftui/view/geometrygroup()) makes a group animate as one frame.

MEASURED-SWIFTUI

```swift
import SwiftUI

struct NowPlayingScreen: View {
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Read in body, so the new arrangement lands in the same update as the new size.
        let isWide = widthClass == .regular
        let layout = isWide
            ? AnyLayout(HStackLayout(alignment: .center, spacing: 24))
            : AnyLayout(VStackLayout(spacing: 16))
        layout {
            Artwork()            // the same view in both layouts: it moves, it doesn't reload
            PlaybackControls()
        }
        // Opt in. Keyed on a discrete value, never on the raw size.
        .animation(reduceMotion ? nil : .smooth, value: isWide)
    }
}
```

### Don't copy the size into state

```swift
// Bad: the arrangement follows the size class one update late.
struct NowPlayingScreenLate: View {
    @Environment(\.horizontalSizeClass) private var widthClass
    @State private var isWide = false          // a copy of the size class

    var body: some View {
        let layout = isWide ? AnyLayout(HStackLayout()) : AnyLayout(VStackLayout())
        layout {
            Artwork()
            PlaybackControls()
        }
        .onChange(of: widthClass) { _, newClass in
            withAnimation(.smooth) { isWide = newClass == .regular }   // a second update
        }
    }
}
```

MEASURED-MIRROR

The same goes for `DispatchQueue.main.asyncAfter`, a `Task.sleep` before a state change, or an animation started in `onAppear`: each one animates after the resize, so people see the window change and then the content move. When a value only exists after layout (the fold's frame, an exact width), [`onGeometryChange(for:of:action:)`](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)) is the right tool. Keep its action to one cheap state write, and key the animation on what you derive. MEASURED-GEOMETRY

## Rules

1. **Same views, new places.** Switch layouts with `AnyLayout`, `ArrangementView` or one container, and give `ForEach` stable IDs. A branch on size class, a `ViewThatFits` that swaps children, or an `.id` fed by layout creates new views. New views can't move from their old frame: they fade or pop, and lose their state ([AnyLayout](https://developer.apple.com/documentation/swiftui/anylayout), `duo-continuity`).
2. **Animate with the size change, not after it.** See above. In UIKit, change layout inside the coordinator's alongside block, not in its completion.
3. **Controls keep their place and their look.** Same symbol, title, order, style and tint at every size. Keep their positions relative to each other as similar as you can across poses ([HIG, Vertical controls](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls)). Keep a control's edge: bottom stays bottom. Move one only to clear the fold, to the nearest region (`duo-patterns`, displacement).
4. **Small moves, one property at a time.** Favour small adjustments over rearranging ([HIG, Reserved regions](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions)). Moving an element far from where it was weakens its link to the content ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=206)). Don't change a control's position, size and style in the same change.
5. **No reload flash.** See the table below.
6. **Keep the reader's place.** Scrolling content is not displaced ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=225)). Anchor scroll views by item ID, keep selection in a model (`duo-continuity`).
7. **Let the system animate its own parts.** Bars, sheets, alerts, menus and split view columns move off the fold and between axes on their own ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=571)). Don't animate them again.
8. **Respect Reduce Motion.** See below.
9. **Keep each update cheap.** At 120 Hz a frame has about 8.3 ms ([Understanding hitches](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app)), and a fold lays out the whole window at once.

## No reload flash

| You see | Usual cause | Fix |
|---|---|---|
| A blank or white frame | A background that differs by size class, or a view rebuilt before it has content | One background for every size; stable identity |
| A spinner or placeholder | A fetch in `onAppear` or `.task` that runs again because the view was rebuilt, or `.task(id:)` keyed on size | Load once, in a model (`duo-continuity`) |
| Images blink | `AsyncImage` rebuilt, so it starts empty and loads again | Stable identity; keep loaded images in a model or cache |
| Everything fades in | `onAppear { withAnimation { opacity = 1 } }` on a layout view | No appearance animation on views that a fold rebuilds |
| The list jumps to the top | New identity, or a saved offset restored | `ScrollPosition` by item ID (`duo-continuity`) |
| UIKit cells flash | `reloadData()` or new child view controllers on a trait change | Invalidate the layout inside the coordinator |

## SwiftUI patterns

Full code for each: [references/swiftui.md](references/swiftui.md).

| Need | Pattern |
|---|---|
| Stacked closed, side by side open | `AnyLayout` and `.animation(_:value:)`, above |
| A pane that only exists open | `if isWide` inside a container that never changes, `.transition(.opacity)` |
| One picture that changes container (mini player artwork into a player pane) | [`matchedGeometryEffect`](https://developer.apple.com/documentation/swiftui/view/matchedgeometryeffect(id:in:properties:anchor:issource:)) on that stateless element only |
| Grid columns | Stable `ForEach` IDs, the animation keyed on the column count |
| Controls off the fold | `FoldGeometry` and `.animation(.smooth, value: fold)`, from `duo-patterns` |
| Text that changes with the size | `.contentTransition(.identity)`, or `.interpolate` for a size change of the same string |
| A part that must snap | `.animation(nil, value:)` on it, under the animated parent |

```swift
struct LibraryScreen: View {
    @Environment(\.horizontalSizeClass) private var widthClass
    let albums: [Album]

    var body: some View {
        let isWide = widthClass == .regular
        let layout = isWide ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
        layout {
            LibraryHeader(title: isWide ? "Your Library" : "Library")
                .contentTransition(.identity)    // the header moves; its text swaps without a fade
            AlbumFeed(albums: albums, columns: isWide ? 4 : 2)
                .animation(nil, value: isWide)   // the whole feed, frame included, snaps into place
        }
        .animation(.smooth, value: isWide)
    }
}
```

## UIKit

```swift
import UIKit

final class PlayerViewController: UIViewController {
    private var tallConstraints: [NSLayoutConstraint] = []
    private var wideConstraints: [NSLayoutConstraint] = []

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let isWide = size.width > size.height          // decide from the size you are given
        coordinator.animate(alongsideTransition: { _ in
            self.applyLayout(isWide: isWide)           // same views, new constraints
            self.view.layoutIfNeeded()                 // lay out inside the system's animation
        }, completion: { _ in
            // After the resize: work that must not animate, such as prefetching.
        })
    }

    private func applyLayout(isWide: Bool) {
        NSLayoutConstraint.deactivate(isWide ? tallConstraints : wideConstraints)
        NSLayoutConstraint.activate(isWide ? wideConstraints : tallConstraints)
    }
}
```

- [`viewWillTransition(to:with:)`](https://developer.apple.com/documentation/uikit/uicontentcontainer/viewwilltransition(to:with:)) runs before the size changes. Always call `super`. Blocks you pass to [`animate(alongsideTransition:completion:)`](https://developer.apple.com/documentation/uikit/uiviewcontrollertransitioncoordinator/animate(alongsidetransition:completion:)) run in the same animation group as the system's transition.
- MEASURED-UIKIT
- Collection views: invalidate the layout inside the alongside block. Never call `reloadData()` there. Keep the top item in view as `duo-continuity` shows.
- A partial fold has no coordinator. Re-read reserved regions in `viewDidLayoutSubviews` and animate with [`UIView.animate(_:changes:completion:)`](https://developer.apple.com/documentation/uikit/uiview/animate(_:changes:completion:)) (iOS 18), which takes a SwiftUI `Animation`. That method is declared in SwiftUI, so the file needs `import SwiftUI`.
- Full code: [references/uikit.md](references/uikit.md).

## Reduce Motion

- Apple's guidance: replace movement along x, y and z with fades, tighten springs, and avoid animating depth and blur ([HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Cognitive)).
- Read it: SwiftUI [`accessibilityReduceMotion`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion), and [`accessibilityPrefersCrossFadeTransitions`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityprefersCrossFadeTransitions) from iOS 26.4. UIKit `UIAccessibility.isReduceMotionEnabled`, `UIAccessibility.prefersCrossFadeTransitions` and `reduceMotionStatusDidChangeNotification`.
- For a fold: layout moves get no animation, so views take their new place at once. A pane that appears gets a short fade. Effects driven by the hinge angle (zoom, parallax, tilt) turn off.

```swift
extension Animation {
    /// The animation for a layout change caused by a fold or a resize.
    /// Nil under Reduce Motion: views take their new place at once.
    static func resize(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .smooth(duration: 0.35)
    }
}
```

MEASURED-TRANSITION

## 120 Hz ProMotion

- Both displays have ProMotion up to 120 Hz ([specs](https://www.apple.com/iphone-duo/specs/)). SwiftUI, UIKit and Core Animation pace their animations for it on their own ([Optimizing ProMotion](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays)). A `.smooth` spring needs no extra code.
- The budget is the hard part: about 8.3 ms per frame for your main thread. Keep `body` free of sorting, filtering, formatting and image decoding. Don't put a `GeometryReader` in every row. Use lazy stacks for long content.
- Custom per-frame drawing with `CADisplayLink`: set `preferredFrameRateRange`, pace by `targetTimestamp`, and add `CADisableMinimumFrameDurationOnPhone` to Info.plist, or iPhone stays at 60 Hz for it. Code: [references/performance.md](references/performance.md).
- The hinge angle streams continuously. Use it for effects, never to run layout every frame ([talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/?time=154)).
- *Measured:* the simulator reports `maximumFramesPerSecond` = 60. It can't show 120 Hz or hitches.

## What not to animate

| Don't animate | Why | Instead |
|---|---|---|
| Scroll position, or a feed moving between halves | Scrolling content already adapts; moving it breaks continuity | Anchor by item ID; let it reflow |
| Bars, sheets, alerts, menus, split view columns | The system moves them already; a second motion fights it | Nothing |
| The raw window size | It changes many times during a drag; a spring lags behind | A discrete key: width class, column count, fold state |
| Layout from the hinge angle | A continuous stream, meant for effects | Reserved regions and arrangements |
| First appearance after a fold | Reads as a reload | Nothing; a short fade only for a pane that is new |
| A different background or font size per display | A flash, and text that cross-fades | One background; the same type size |
| Position, size and style of one control together | Hard to follow | Move it; keep its look |
| Zoom, 3D or blur on resize | Uncomfortable, and Reduce Motion asks you not to | A plain move or a fade |

## What only a real device shows

- Whether the hand-over between the two displays looks continuous. MEASURED-DEVICE
- Smoothness at 120 Hz and hitches during open and close. The simulator tops out at 60.
- How a spring feels at the speed people really open the phone, and whether your motion lines up with the system's.
- Frame rates that drop in Low Power Mode or when the phone is hot ([Optimizing ProMotion](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays)).

Until Duology has run on hardware, its `metadata.verified` says `device: no`. Say so in your own review notes.

## Test it

1. In Device Hub, choose Device > Slow Animations ([Device Hub](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)). Press Closed, Open and Partially Open, rotate, and drag the app into Split View.
2. Record the inner display while you press Open: `xcrun simctl io <UDID> recordVideo --display=primary-1 open.mov` (`primary` is the outer display). Step through it frame by frame. Look for a blank frame, a pop then a glide, a jump to the top, a control that vanishes and comes back.
3. While debugging, log the transaction that reaches a view (`logTransaction` in [references/swiftui.md](references/swiftui.md#see-what-a-change-hands-you)) to see whether a change arrives animated.
4. Turn on Reduce Motion in the simulator's Settings and repeat steps 1 and 2.
5. On a device, run Instruments' Animation Hitches template while you open and close the phone.

## Red flags in review

- `withAnimation` in `onChange(of: horizontalSizeClass)` that copies the size class into `@State`
- `.animation(_:value:)` keyed on `proxy.size`, a width or a `CGSize`
- `if sizeClass == .compact { A } else { B }` with the same views in both branches; `.id(sizeClass)`
- `DispatchQueue.main.asyncAfter`, `Task.sleep` or `onAppear` animations after a size change
- A background colour, font size or button style chosen by size class
- UIKit: layout changes in the coordinator's completion block; `reloadData()` in `viewWillTransition(to:with:)` or a trait handler
- No `accessibilityReduceMotion` or `isReduceMotionEnabled` check next to custom motion

## Checklist

- [ ] Layout comes from the size class or the view's size, read in `body`; no copy of the size class in `@State`.
- [ ] Layout switches keep identity: `AnyLayout`, `ArrangementView` or one container; stable `ForEach` IDs; no `.id` fed by layout.
- [ ] Every `.animation(_:value:)` is keyed on a discrete value, never on the raw size.
- [ ] Parts that must snap opt out with `.animation(nil, value:)`, a leaf `transaction`, or `contentTransition(.identity)`.
- [ ] Controls keep their symbol, title, order, style and tint at every size, and keep their edge.
- [ ] No blank frame, spinner, blinking image or fade-in after close, open or rotate.
- [ ] Scroll position and selection survive (`duo-continuity`).
- [ ] UIKit layout changes run inside `animate(alongsideTransition:completion:)`; no `reloadData()` on a resize.
- [ ] Reduce Motion: no movement, short fades only; hinge effects off.
- [ ] `body` does no heavy work; custom display links use `preferredFrameRateRange` and `targetTimestamp`.
- [ ] Checked in Device Hub with Slow Animations, and in a recording of the inner display. Smoothness at 120 Hz left for a device, and said so.
