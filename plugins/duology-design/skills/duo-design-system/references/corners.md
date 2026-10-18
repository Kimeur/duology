# Corners that fit both displays

iPhone Duo has two displays with two different corner shapes. Apple doesn't publish either radius, and it doesn't need to: the concentricity APIs from iOS 26 know both shapes. Apple's Duo talk tells you to use them, `ConcentricRectangle` in SwiftUI and `UICornerConfiguration` in UIKit, so your UI fits the corners of each screen ([111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=258)).

## The model

A corner is concentric with its container when both curves share a centre. Its radius is the container's radius minus the distance between the two corners ([`concentric(minimum:)`](https://developer.apple.com/documentation/swiftui/edge/corner/style/concentric(minimum:))). Apple's design system uses three kinds of shape ([Get to know the new design system](https://developer.apple.com/videos/play/wwdc2025/356/?time=222)):

| Shape | Radius | Use for |
|---|---|---|
| Fixed | a constant | standalone cards and tiles in scrolling content |
| Capsule | half the height | buttons, chips, sliders: touch controls |
| Concentric | container radius minus padding | anything near a display corner, or nested in a rounded container |

A concentric corner far from its container's corner gets a radius of 0. A minimum radius fixes that: concentric when nested, the minimum when alone ([ConcentricRectangle](https://developer.apple.com/documentation/swiftui/concentricrectangle), [Get to know the new design system](https://developer.apple.com/videos/play/wwdc2025/356/?time=366)). `DuoTokens.innerRadius` (8 pt) is that minimum.

`DuoTokens.cardRadius` is `cardPadding + innerRadius`, so the first nested element in a card lands on exactly `innerRadius`. *Measured* offscreen on the iOS 27.1 simulator runtime with `GeometryProxy.concentricCornerRadii`:

| Child inset | Container radius | Child radius |
|---|---|---|
| 16 pt | 24 pt (compact card) | 8 pt on all four corners |
| 20 pt | 28 pt (regular card) | 8 pt on all four corners |
| 20 pt | 24 pt | 4 pt (under the minimum; `.concentric(minimum:)` would use 8) |
| 8 pt, a strip along the top edge only | 24 pt | 16 pt top corners, 0 pt bottom corners |
| 16 pt, no container shape declared | none | 0 pt (Apple's doc says `nil` here; in our offscreen render it was 0) |
| 16 pt, a 64 pt thumbnail at the leading edge of a compact `DuoCard` | 24 pt | 8 pt leading corners, 0 pt trailing corners |
| 16 pt, under `.background(_:in:)` with no `containerShape` inside it | 24 pt | `nil` |

We also checked the drawn shape, pixel by pixel. A `ConcentricRectangle(corners: .concentric(minimum: .fixed(8)))` inset 16 pt in a 48 pt container drew the same corner as a fixed 32 pt radius, whether we used it as a view, as the shape of `.background(_:in:)` or through `.clipShape(.rect(corners:))`. With no container it drew the 8 pt minimum. Under a parent's `.background(_:in: .rect(cornerRadius: 48))` alone it also drew 32 pt, although `concentricCornerRadii` read `nil` there. So apply `.containerShape(_:)` before `.background(_:in:)` in the modifier chain, as `DuoCard` does, and both APIs agree.

## Rules

1. Anything that touches or nearly touches a display edge (a bottom panel, a full-width sheet-like card, a floating toolbar) uses `ConcentricRectangle` or `.rect(corners: .concentric(minimum:))` for the corners near that edge.
2. Never hard-code a display corner radius. The two displays differ, and other iPhones differ again.
3. Declare the shape of every custom rounded container with `.containerShape(_:)`, before any `.background(_:in:)` on it, so concentric children inside it can resolve. System sheets, popovers and the window already provide one ([ConcentricRectangle](https://developer.apple.com/documentation/swiftui/concentricrectangle)).
4. Controls are capsules. Near a screen edge on a phone, give a capsule button extra margin from the edge ([Get to know the new design system](https://developer.apple.com/videos/play/wwdc2025/356/?time=348)).
5. Cards in scrolling content use a fixed radius (`tokens.cardRadius`). Their children use concentric corners against the card.
6. Watch for corners that look pinched or flared, mostly in nested containers. The fix is usually a concentric inner shape ([Get to know the new design system](https://developer.apple.com/videos/play/wwdc2025/356/?time=319)).

## Code

Typechecked against the iOS 27.1 simulator SDK in Swift 5, Swift 6 and main actor default isolation modes, and with an iOS 17 deployment target. The concentric views need iOS 26; `concentricCornerRadii` needs iOS 27.0.

A bottom panel: fixed top corners, bottom corners concentric with the display.

```swift
import SwiftUI

// requires: DuoTokens.swift

@available(iOS 26.0, *)
struct BottomPanel<Content: View>: View {
    @DuoMetrics private var tokens
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(tokens.cardPadding)
            .frame(maxWidth: .infinity)
            .background(DuoColor.card, in: ConcentricRectangle(
                uniformTopCorners: .fixed(tokens.cardRadius),
                uniformBottomCorners: .concentric(minimum: .fixed(DuoTokens.innerRadius))))
            .padding(DuoSpace.x2)   // a small inset from the display edge
    }
}
```

On the outer display and on the inner display the same code follows each display's corner. When the panel sits inside a pane away from the display corners, its bottom corners fall back to 8 pt.

A thumbnail in a `DuoCard` (from [tokens.md](tokens.md)), concentric with the card:

```swift
import SwiftUI

// requires: DuoTokens.swift

@available(iOS 26.0, *)
struct CardWithThumbnail: View {
    var body: some View {
        DuoCard {
            HStack(spacing: DuoSpace.x3) {
                Color.teal
                    .frame(width: 64, height: 64)
                    .clipShape(.rect(corners: .concentric(minimum: .fixed(DuoTokens.innerRadius))))
                Text("Lisbon").font(DuoType.itemTitle)
            }
        }
    }
}
```

The thumbnail's leading corners sit 16 pt in from the card's corners, so they resolve to a concentric 8 pt. Its trailing corners are far from any card corner and resolve to 0, so the 8 pt minimum applies (*measured*, see the table above). Same result, by two routes.

A custom container that declares its shape:

```swift
import SwiftUI

// requires: DuoTokens.swift

@available(iOS 26.0, *)
struct MediaTile: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.indigo
            Text("Now Playing")
                .font(DuoType.caption)
                .padding(DuoSpace.x2)
                .background(.thinMaterial, in: ConcentricRectangle(
                    corners: .concentric(minimum: .fixed(DuoTokens.innerRadius))))
                .padding(DuoSpace.x2)
        }
        .frame(height: 180)
        .clipShape(.rect(cornerRadius: 24))
        .containerShape(.rect(cornerRadius: 24))
    }
}
```

The radii themselves, for custom drawing (iOS 27.0):

```swift
import SwiftUI

// requires: DuoTokens.swift

@available(iOS 27.0, *)
struct ConcentricOutline: View {
    var body: some View {
        GeometryReader { proxy in
            let radii = proxy.concentricCornerRadii ?? RectangleCornerRadii(
                topLeading: DuoTokens.innerRadius, bottomLeading: DuoTokens.innerRadius,
                bottomTrailing: DuoTokens.innerRadius, topTrailing: DuoTokens.innerRadius)
            Path(roundedRect: CGRect(origin: .zero, size: proxy.size), cornerRadii: radii)
                .stroke(.tint, lineWidth: 2)
        }
        .padding(DuoSpace.x2)
    }
}
```

A capsule action near the bottom edge:

```swift
import SwiftUI

// requires: DuoTokens.swift

@available(iOS 26.0, *)
struct EdgeActionButton: View {
    var body: some View {
        Button("Continue") {}
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.horizontal, DuoSpace.x6)
            .padding(.bottom, DuoSpace.x2)
    }
}
```

UIKit: `view.cornerConfiguration = .corners(radius: .containerConcentric(minimum: DuoTokens.innerRadius))` (iOS 26). See [uikit.md](uikit.md).

## Pitfalls

- **A radius copied from a screenshot.** It fits one display and one device.
- **A concentric shape with no minimum, in the middle of the screen.** It turns square. Add `minimum:`.
- **Concentric corners on cards in a long list.** Use a fixed radius for scrolling cards, so they look the same at every position. (Duology's choice; we have not measured how a scrolling concentric card behaves near the display corners.)
- **No `containerShape` on a custom container.** Children have nothing to be concentric with.
- **`containerShape` after `.background(_:in:)`.** `GeometryProxy.concentricCornerRadii` then read `nil` in our test. Apply `.containerShape(_:)` first, then the background.
- **A 24 pt card with 20 pt padding and an 8 pt child.** The child looks flared. Keep `cardRadius = cardPadding + innerRadius`.

## Test it

1. Screenshot the outer display and the inner display with a bottom panel showing (`xcrun simctl io booted screenshot --display=primary` and `--display=primary-1`). Zoom on the corners: the panel's curve runs parallel to the display's.
2. Open Split View: a panel in the left app follows only the corners it touches.
3. Rotate: the corners still match.
