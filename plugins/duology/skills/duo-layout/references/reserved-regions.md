# Reserved regions

How to find the fold and the cameras inside your view, and move your own controls out of the way. System containers and presentations already do this; you only need it for custom views.

Apple sources: [ReservedRegion](https://developer.apple.com/documentation/swiftui/reservedregion), [reservedRegions(kind:options:layoutDirectionBehavior:)](https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:)), [UIView.ReservedRegion](https://developer.apple.com/documentation/uikit/uiview/reservedregion), [Tech Talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=399), [HIG: Reserved regions](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions).

## The API

| | SwiftUI | UIKit |
|---|---|---|
| Query | `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)` | `UIView.reservedRegions(kind:options:)` |
| Region type | `ReservedRegion` | `UIView.ReservedRegion` |
| Kinds | `.division`, `.occlusion` | `.division`, `.occlusion` |
| Options | `.includeInactive` | `.includeInactive` |
| Region fields | `id`, `kind`, `frame`, `margins` (`EdgeInsets`), `isActive` | `id`, `kind`, `frame`, `margins` (`UIEdgeInsets`), `isActive` |
| Available | iOS 27.1 | iOS 27.1 |

There is no singular `reservedRegion` method, and no posture or pose API. The talk's narration says "reservedRegion"; the SDK only has the plural.

- `frame` is in the view's own coordinate space and **includes** `margins`. The margins add room for touch targets around the reserved area.
- SwiftUI mirrors frames for right-to-left layouts by default (`layoutDirectionBehavior: .mirrors`). Code that places views with `Layout`, `.position` or offsets then works in both directions without changes. Pass `.fixed` only when you need physical coordinates.

## What we measured

Probe app on the iPhone Duo simulator, iOS 27.1, fully open (hinge `fullyOpen`, 180°), held wide, window 951 × 669 pt, no camera running.

| Query | Result |
|---|---|
| `.division`, no options | `[]` |
| `.division`, `.includeInactive` | one region, `isActive == false`, frame x 455, y 0, 40 × 669, margins 20 left and 20 right |
| `.occlusion`, no options | one region, active, frame x 867, y 0, 84 × 124 (top-trailing corner) |
| `.occlusion`, `.includeInactive` | two regions: the active one above, plus an inactive one at x 677, y 21, 58 × 37 |
| Any query on the very first layout pass | `[]`; values arrived on the next pass |

UIKit's `reservedRegions(kind:options:)` returned the same frames. A separate probe app on the same simulator got identical numbers.

What this tells you:

- **The default query skips inactive regions.** This matches the talk. Apple's `ReservedRegion` page says the query returns regions "regardless" of active state; our results contradict that page. Always filter on `isActive` yourself so your code is right either way.
- **Flat, the fold is a zero-width line.** The 40 pt frame is the line at x 475.5 (the centre of 951) plus 20 pt of margin on each side.
- **The inactive occlusion is most likely the inner camera**, which is off until something uses it. The active occlusion at the top-trailing corner sits where the inner display shows its status bar. Apple doesn't label either region; this is our reading of the positions.
- **Frames move with the view.** When our probe view grew past the window, every frame shifted by the same amount. They are local coordinates, not screen coordinates.

Not yet measured: the division's width and position while partly folded, regions in Split View, and regions on the outer display. Folding needs Device Hub's pose buttons, and we have not run the probe folded yet.

## Read regions in SwiftUI

Read them from a `GeometryProxy`: inside `GeometryReader`, or with `onGeometryChange(for:of:action:)` when you only need a value. Keep the result optional and treat `nil` as "no fold".

```swift
import SwiftUI

struct FoldAwareScreen: View {
    @State private var fold: CGRect?

    var body: some View {
        ScreenContent(fold: fold)
            .onGeometryChange(for: CGRect?.self) { proxy in
                proxy.reservedRegions(kind: .division)
                    .first(where: \.isActive)?
                    .frame
            } action: { newFold in
                fold = newFold
            }
    }
}
```

Use active regions for **placement** (where a button goes right now). Use `.includeInactive` for **structure** that should not jump when someone folds (column counts, whether to plan for two halves). Apple suggests exactly this split in [111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=470).

## Displace controls, not content

Apple's displacement pattern ([111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=146)):

- Move a single element when it stands alone. Move a group together when its parts belong together.
- Don't move things far from what they relate to.
- Never displace continuous scrolling content (articles, feeds, documents, lists). It already adapts by scrolling.
- Folded like a book, alerts and similar items belong on the trailing side, close to where they reappear when the phone closes.
- Propped on a table like a laptop, the top area suits content seen from a distance; the bottom area suits controls you tap.

`FoldAvoidingControls` in [SKILL.md](../SKILL.md#3-reserved-regions-the-fold-and-the-cameras) moves a group to the trailing or bottom side. The player below handles the laptop case: video above the fold, the same controls below it, and the video view never leaves the hierarchy, so playback is not interrupted.

```swift
import SwiftUI

struct FoldAwarePlayer: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let fold = proxy.reservedRegions(kind: .division).first(where: \.isActive)?.frame
            // A fold that runs side to side (frame wider than tall): the top half faces
            // the viewer, as when the phone sits on a table like a laptop.
            let sideToSide = fold.map { $0.width > $0.height } ?? false
            let videoHeight = sideToSide ? (fold?.minY ?? size.height) : size.height
            let controlsHeight: CGFloat? = sideToSide ? size.height - (fold?.maxY ?? 0) : nil

            ZStack(alignment: .top) {
                VideoSurface()
                    .frame(width: size.width, height: videoHeight)
                PlayerControls()
                    .frame(width: size.width, height: controlsHeight)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}
```

Keep the same controls and hierarchy in every pose. Apple calls a special laptop layout optional, and it must not add or remove features ([111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=222)).

## Even grid columns

The HIG asks for an even number of columns so the fold falls between cells ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions)). A grid in a `ScrollView` is scrolling content, so it may cross the fold.

```swift
import SwiftUI

struct PhotoGrid: View {
    let photos: [Photo]

    var body: some View {
        GeometryReader { proxy in
            let hasFold = !proxy.reservedRegions(kind: .division, options: .includeInactive).isEmpty
            let count = Self.columnCount(width: proxy.size.width, minimumCell: 110, hasFold: hasFold)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: count), spacing: 8) {
                    ForEach(photos) { photo in
                        PhotoCell(photo: photo)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    static func columnCount(width: CGFloat, minimumCell: CGFloat, hasFold: Bool) -> Int {
        let fit = max(1, Int(width / minimumCell))
        guard hasFold, fit > 1 else { return fit }
        return fit.isMultiple(of: 2) ? fit : fit - 1
    }
}
```

The middle gap only lines up with the fold when the grid is centred on the display. If a vertical bar sits on one side, the grid's centre moves off the fold. For a grid of controls (not scrolling content), Apple's Fitness example keeps the outer margins and widens the gap around the fold instead ([111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=312)).

## Occlusions

Most apps never need to read occlusions: the outer camera sits beside the vertical bars, and the safe area already covers it. Read them when you draw edge to edge, for example a custom bar, a full-screen game HUD or a camera viewfinder.

```swift
import SwiftUI

enum CornerBadge {
    /// The y position for a badge in the top-trailing corner that stays clear of active occlusions.
    static func top(for badge: CGSize, in proxy: GeometryProxy, padding: CGFloat = 8) -> CGFloat {
        let corner = CGRect(
            x: proxy.size.width - badge.width - padding,
            y: padding,
            width: badge.width,
            height: badge.height
        )
        let blockers = proxy.reservedRegions(kind: .occlusion)
            .filter(\.isActive)
            .map(\.frame)
            .filter { $0.intersects(corner) }
        guard let lowest = blockers.map(\.maxY).max() else { return padding }
        return lowest + padding
    }
}
```

When the inner camera turns on, its occlusion becomes active and the system moves its own UI aside. If your viewfinder or a key control sits there, move it too ([111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=27)).

## UIKit

Query in `viewDidLayoutSubviews()` or `layoutSubviews()`. Code: [uikit.md](uikit.md#reserved-regions).

## Open questions

- Does a fold alone (no size change) trigger a new SwiftUI geometry pass or UIKit layout pass? Apple's examples read regions in `GeometryReader` and `onGeometryChange`, which implies yes. Not tested here. (unverified)
- Is the division ever reported to an app in Split View, where the fold falls between two apps? (unverified)
- How wide is the active division at different hinge angles? (unverified)
