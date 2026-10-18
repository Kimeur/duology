# What we measured

Depth for [`../SKILL.md`](../SKILL.md). Every *measured* claim in this skill comes from the runs below.

## Setup

- Xcode 27.1 (27A9275), the shared iPhone Duo simulator on iOS 27.1, 18 October 2026.
- The phone was **closed, portrait** for every run: the outer display, a 466 × 678 pt window.
- A small SwiftUI probe app, built with `swiftc` for `arm64-apple-ios27.1-simulator`. It contained the `ThumbCorner` and `auditTarget(_:)` code from this skill, a `NavigationStack` with Close (`.cancellationAction`), Done (`.topBarPinnedTrailing`) and a `.bottomBar` group (Share, Delete), and a logging view like the one below.
- Launched with `xcrun simctl launch --console-pty`. Right to left was forced with the launch arguments `-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES`.
- Screenshots: `xcrun simctl io <UDID> screenshot --display=primary`.

## Results

### The bar and the content area

| | Left to right | Right to left (forced) |
|---|---|---|
| Bar position in the screenshot | right edge | right edge |
| `toolbarVerticalEdge` | `.trailing` | `.leading` |
| `layoutDirection` | `.leftToRight` | `.rightToLeft` |
| Size classes | compact width, regular height | compact width, regular height |
| Safe area: leading, trailing, top, bottom | 0, 84, 82, 34 pt | 84, 0, 82, 34 pt |
| `contentMargins(for: .container)`: leading, trailing | 20, 0 pt | 0, 20 pt |
| Content area (inside the safe area) | 382 × 562 pt, x 0–382, y 82–644 | the same |
| Title | top left | top right |

- The top inset of 82 pt holds the large title, which stays horizontal at the top of the content.
- Close and Done sat at the top of the vertical bar, under the time and status icons. Share and Delete sat at its foot, level with the bottom of the content.
- The first layout pass reported a 382 × 514 pt content area with an 82 pt bottom inset; the next pass settled at 562 pt and 34 pt. Read geometry after it settles.

### Floating control (`ThumbCorner`, 56 × 56 pt button)

| Run | Frame in window points | Where |
|---|---|---|
| Left to right, `.automatic` | x 310–366, y 572–628 | bottom right, beside the bar's foot |
| Right to left, `.automatic` | x 310–366, y 572–628 | bottom right: `.bottomLeading` mirrored onto the bar's side |
| Left to right, `.left` | x 16–72, y 572–628 | bottom left |

`frame(in: .global)` gave the same numbers in both directions, so global frames are not mirrored. Reserved-region frames are: the outer camera's occlusion came back at x 399–436 left to right and at x −54 to −17 right to left (the default `layoutDirectionBehavior` mirrors them, as Apple's doc says).

### Reserved regions, closed

- Division (the fold): none, with or without `.includeInactive`.
- Occlusion: two active regions, both in the bar strip: x 399–436, y −52 to −15 (37 × 37 pt, the outer camera) and x 382–466, y −82 to 92 (84 × 174 pt, the status bar area). Frames are in the content view's coordinates, so both lie outside its 382 × 562 pt frame. `duo-layout` measured the same two sizes.

### Control sizes (layout frames, default text size)

| Control | Size |
|---|---|
| `.borderedProminent`, `.regular` | 82 × 34 pt ("Regular") |
| `.borderedProminent`, `.large` | 83 × 50 pt ("Large") |
| `.borderedProminent`, `.extraLarge` | 95 × 50 pt ("XLarge") |
| Plain text button | 37 × 21 pt ("Plain") |
| Plain icon-only button | 18 × 16 pt |
| Icon-only button with `.frame(minWidth: 44, minHeight: 44)` and `.contentShape(.rect)` | 44 × 44 pt |

### Overlay arrangement, closed

`ArrangementView` with `.overlay`, the controls as the primary with `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)`:

- primary: x 0–382, y 82–644 (the whole content area);
- secondary: x 0–382, y 82–644;
- the control strip itself: x 106–276, y 576–643, bottom centre.

### Target audit, closed

```text
TARGET tiny: 22 x 13 pt, under 44 pt
TARGET centre: 103 x 34 pt, under 44 pt
```

## Not measured

We planned the same runs open, in book and in tabletop poses, by pressing Device Hub's pose buttons through the macOS Accessibility API (see `duo-setup`). Device Hub had a window on screen, but its accessibility tree came back empty: the window had no children and the app returned "attribute unsupported" for its children. No pose button could be pressed, so the pose never changed and every run above is closed. Still to check:

- `toolbarVerticalEdge` and the floating button on the inner display, held wide and held tall, in both directions.
- The overlay arrangement folded: controls in the bottom half in tabletop, and on the bar's half in book with `overlayArrangementEdge(_:)`.
- `auditTarget(_:)` reporting a control on an active fold.
- Split View on each side.
- Everything on a real iPhone Duo, including how firm the hinge feels when someone taps the raised half on a table.

## Rerun

Add this view to any screen, switch poses in Device Hub, and read the console. It typechecks against the iOS 27.1 simulator SDK.

```swift
import SwiftUI

/// Logs the bar edge, layout direction, insets, margins and the fold for the space it fills.
@available(iOS 27.1, *)
struct ErgonomicsProbe: View {
    @Environment(\.toolbarVerticalEdge) private var barEdge
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        Color.clear.onGeometryChange(for: String.self) { proxy in
            let inset = proxy.safeAreaInsets
            let margin = proxy.contentMargins(for: .container, edges: .horizontal)
            let folds = proxy.reservedRegions(kind: .division, options: .includeInactive)
                .map { "\($0.frame) active=\($0.isActive)" }
            return "size=\(proxy.size) safe(L \(inset.leading) T \(inset.trailing) B \(inset.bottom)) "
                + "margins(L \(margin.leading) T \(margin.trailing)) folds=\(folds)"
        } action: { geometry in
            print("ERGONOMICS bar=\(String(describing: barEdge)) dir=\(direction)", geometry)
        }
    }
}
```

Put it in a `ZStack` behind your content, or in an `.overlay`, so it fills the same space as the content you lay out.
