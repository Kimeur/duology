# What we measured

Depth for [`../SKILL.md`](../SKILL.md). Every claim this skill marks *measured* comes from the runs below, unless it names another Duology skill (`duo-layout`, `duo-patterns`) as the source. A claim that doesn't say open comes from the closed runs.

## Setup

- Xcode 27.1 (27A9275), the shared iPhone Duo simulator on iOS 27.1, 18 October 2026.
- Two sets of runs, in the pose the simulator was already in. We never pressed a pose button (see [Not measured](#not-measured)).
  - **Closed, portrait**: the outer display, a 466 × 678 pt window.
  - **Open and flat, held wide** (later the same day): the inner display, a 951 × 669 pt window. `xcrun devicectl device info displays` showed the inner display (`LCD-1`) active at `rot90`, before and after each run.
- Small SwiftUI probe apps, built with `swiftc` for `arm64-apple-ios27.1-simulator`.
  - The closed probe held the `ThumbCorner` and `auditTarget(_:)` code from this skill, a `NavigationStack` with Close (`.cancellationAction`), Done (`.topBarPinnedTrailing`) and a `.bottomBar` group (Share, Delete), and a logging view like the one below.
  - The open probe held section 3's `PlayerScreen` and `PlayerControls` as printed in `SKILL.md`, with logging modifiers added, and a screen of buttons at several control sizes.
- Launched with `xcrun simctl launch --console-pty`. Right to left was forced with the launch arguments `-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES`.
- Screenshots: `xcrun simctl io <UDID> screenshot --display=primary` (outer display) or `--display=primary-1` (inner display).
- Every size below is a layout frame from `onGeometryChange`. It shows where a view sits, not which points take taps. See [Hit regions](#hit-regions).

## Closed, portrait

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

### Floating control (`ThumbCorner`)

The probe's button had `.frame(width: 56, height: 56)` and its background outside the `Button`. The numbers are that outer frame. Section 2 of `SKILL.md` now puts the frame on the label, which gives a button of the same size (the open run below measured 56 × 56 pt buttons built that way) and a hit region that matches it.

| Run | Frame in window points | Where |
|---|---|---|
| Left to right, `.automatic` | x 310–366, y 572–628 | bottom right, beside the bar's foot |
| Right to left, `.automatic` | x 310–366, y 572–628 | bottom right: `.bottomLeading` mirrored onto the bar's side |
| Left to right, `.left` | x 16–72, y 572–628 | bottom left |

`frame(in: .global)` gave the same numbers in both directions, so global frames are not mirrored. Reserved-region frames are: the outer camera's occlusion came back at x 399–436 left to right and at x −54 to −17 right to left (the default `layoutDirectionBehavior` mirrors them, as Apple's doc says).

### Reserved regions

- Division (the fold): none, with or without `.includeInactive`.
- Occlusion: two active regions, both in the bar strip: x 399–436, y −52 to −15 (37 × 37 pt, the outer camera) and x 382–466, y −82 to 92 (84 × 174 pt, the status bar area). Frames are in the content view's coordinates, so both lie outside its 382 × 562 pt frame. `duo-layout` measured the same two sizes.

### Overlay arrangement (an earlier variant)

An earlier version of section 3 aligned the controls with `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)`. Closed, with `ArrangementView` and `.overlay`:

- primary: x 0–382, y 82–644 (the whole content area);
- secondary: x 0–382, y 82–644;
- the control strip itself: x 106–276, y 576–643, bottom centre.

Section 3 now aligns to the bottom corner on the bar's side. That code was measured open; see below.

### Target audit

```text
TARGET tiny: 22 x 13 pt, under 44 pt
TARGET centre: 103 x 34 pt, under 44 pt
```

## Open and flat, held wide

The phone was flat, so the fold was inactive. This screen had no toolbar items; the bar strip held only the time and status icons.

| | Left to right | Right to left (forced) |
|---|---|---|
| Bar strip in the screenshot | right edge | right edge |
| `toolbarVerticalEdge` | `.trailing` | `.leading` |
| Safe area: leading, trailing, top, bottom | 0, 84, 0, 34 pt | 84, 0, 0, 34 pt |
| Content area | 867 × 635 pt, x 0–867, y 0–635 | the same |
| Primary (`PlayerControls` with its `.frame`) | x 0–867, y 0–635 | the same |
| Secondary (the video) | x 0–867, y 0–635 | the same |
| Control strip | x 635–867, y 539–635 (232 × 96 pt) | the same |
| Buttons, left to right on screen, y 559–615 | Back 15 x 655–711, Play x 723–779, Forward 15 x 791–847 | Forward 15, Play, Back 15 (the order mirrors) |
| Each button | 56 × 56 pt; `auditTarget` printed nothing | the same |
| Division with `.includeInactive` | x 456–496, y 0–669, inactive | x 372–412, inactive |

- So the controls sat in the bottom corner next to the bar strip in both directions, far from the fold band.
- The division frame is in the content view's coordinates, and right to left mirrors it: 867 − 496 = 371. It is the same physical band. Our values are rounded to the nearest point; `duo-patterns` reports x 455–495. *Derived:* the band is likely x 455.5–495.5, 40 pt wide around the window's centre (951 / 2 = 475.5).
- The first pass reported an 867 × 611 pt content area with a 24 pt top inset; it settled at 867 × 635 pt and 0 pt.

## Control sizes

Layout frames at the default text size.

Closed, text and icon buttons:

| Control | Size |
|---|---|
| `.borderedProminent`, `.regular` | 82 × 34 pt ("Regular") |
| `.borderedProminent`, `.large` | 83 × 50 pt ("Large") |
| `.borderedProminent`, `.extraLarge` | 95 × 50 pt ("XLarge") |
| Plain text button | 37 × 21 pt ("Plain") |
| Plain icon-only button | 18 × 16 pt |
| Icon-only button with `.frame(minWidth: 44, minHeight: 44)` and `.contentShape(.rect)` | 44 × 44 pt |

Open and flat, icon-only buttons with no frame on the label:

| Control | `.regular` | `.large` | `.extraLarge` |
|---|---|---|---|
| `.bordered`, Back 15 Seconds | 44 × 36 pt | 60 × 52 pt | 60 × 52 pt |
| `.bordered`, Play | 39 × 31 pt | 55 × 47 pt | 55 × 47 pt |
| Default style, `.font(.title)`, Back 15 and Forward 15 | 33 × 36 pt | 33 × 36 pt | not run |
| Default style, `.font(.title)`, Play | 25 × 28 pt | 25 × 28 pt | not run |

- `.controlSize(.large)` grew the bordered buttons by 16 pt each way and left the default-style buttons at their glyph size. `.extraLarge` added nothing over `.large`.
- `auditTarget(_:)` flagged every default-style button and both bordered `.regular` buttons as under 44 pt.

## Hit regions

We measured layout, not taps. One check on hit regions ran on the Mac, on 19 October 2026: SwiftUI in an offscreen `NSHostingView`, with synthetic clicks 20 pt right of the centre of a 56 pt circle, inside the circle but off the glyph. Each case ran with the `.plain`, `.borderless` and default styles:

- `.frame(width: 56, height: 56)` and `.background(.regularMaterial, in: .circle)` outside the `Button`: the off-glyph clicks did nothing. Clicks on the glyph worked.
- The same frame and background on the label, then `.contentShape(.circle)`: the off-glyph clicks fired the action.

iOS builds `Button` on the same SwiftUI hit testing, so we expect the same result there. We did not tap on the simulator, so iOS is *unverified*.

## Not measured

We tried twice on 18 October 2026 to change poses by pressing Device Hub's pose buttons through the macOS Accessibility API (see `duo-setup`). Our process was trusted both times. The first time, Device Hub's window was on screen but exposed no children. The second time, its main window had been closed, so the tree held only the menu bar, and `open -g` did not bring a window back. We did not script Device Hub any further and never pressed a pose button; the open runs above used the pose the simulator was already in. We also waited out UI tests that other sessions were running on the same simulator. Still to check:

- The floating button (`ThumbCorner`) on the inner display, and anything on the inner display held tall.
- The overlay arrangement folded: controls in the bottom half in tabletop, and on the bar's half in book with `overlayArrangementEdge(_:)`.
- `auditTarget(_:)` reporting a control on an active fold.
- Split View on each side.
- Taps on iOS (see [Hit regions](#hit-regions)).
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
