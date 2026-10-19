# Feed reflow

A scrolling grid of items that are all the same kind: photos, products, articles, recipes, videos. The grid adds columns as the window widens. When a fold crosses it, the column count is even, so the fold falls between two columns instead of through a tile.

Prior art: the feed in Android's [canonical layouts](https://developer.android.com/develop/ui/compose/layouts/adaptive/canonical-layouts). Apple's rules: prefer an even number of grid columns ([HIG, Reserved regions](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions)), and prefer even columns whenever a division region is present, active or not ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=470)).

## Use it when

- Items are equivalent and the order matters more than their position on screen.
- More width should show more items, not bigger ones.

Not this pattern: a single column of long text (let it scroll and cap its line length), or one item and its details ([list-detail](list-detail.md)).

## How it behaves

| State | Columns | Middle gap |
|---|---|---|
| Closed (outer display) | As many as fit | Normal spacing |
| Open, flat, held wide | Even: 2, 4, 6… | Normal spacing |
| Open, partly folded like a book | Same even count, half on each side | Exactly the fold's reserved frame |
| Open, held tall | As many as fit; the fold runs across, between rows | Normal spacing |
| Split View, half the display | As many as fit | Normal spacing |

Flat, equal tiles with uneven margins (the vertical bar side has none) put the middle gap a few points off the fold line. `duo-design-review` R5 counts that as Minor. If the gap must sit on the fold line flat too, so folding only widens it, use `DuoColumns` from `duo-design-system` ([grid.md](https://github.com/Kimeur/duology/blob/main/plugins/duology-design/skills/duo-design-system/references/grid.md)).

The grid only changes column count and spacing. It never moves out of the fold as a block. Apple says continuous scrolling content such as feeds and lists does not displace ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=146)), and does not need to avoid the fold ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=568)). Apple's Fitness example keeps every tile tappable by keeping the outer margins and widening the gap at the hinge ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=312)). The recipe does the same.

## Apple APIs

| Need | SwiftUI | UIKit |
|---|---|---|
| The grid | [`LazyVGrid`](https://developer.apple.com/documentation/swiftui/lazyvgrid) with [`GridItem`](https://developer.apple.com/documentation/swiftui/griditem) | `UICollectionViewCompositionalLayout` |
| Is a fold crossing the grid, even when flat? | [`reservedRegions(kind: .division, options: .includeInactive)`](https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:)) | [`reservedRegions(kind:options:)`](https://developer.apple.com/documentation/uikit/uiview/reservedregions(kind:options:)) |
| Re-read it when it changes | [`onGeometryChange(for:of:action:)`](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)) | `viewDidLayoutSubviews` (unverified as a trigger for fold changes) |
| System margins, which can differ per side next to a vertical bar | [`contentMargins(for: .container, edges:)`](https://developer.apple.com/documentation/swiftui/view/contentmargins(for:edges:alignment:)) (iOS 27.1) | `directionalLayoutMargins` |
| A minimum tile size that follows Dynamic Type | [`@ScaledMetric`](https://developer.apple.com/documentation/swiftui/scaledmetric) | `UIFontMetrics.scaledValue(for:)` |

## Rules

1. Pick the column count from the grid's own width and a minimum tile width. Never from the screen, the device or the orientation.
2. If a top-to-bottom fold crosses the grid, round the count down to an even number, at least 2. Do this when the fold is inactive too, so the grid doesn't jump from 5 to 4 columns the moment someone folds the phone.
3. While the fold is active, make the middle gap the fold's frame and put half the columns on each side. The two halves can differ a little in width, because a vertical bar takes space on one side only. Let them.
4. Keep only the fold's x values in the state you compare. A region's frame is in the grid's coordinate space, so its y changes as you scroll. Comparing the whole frame would rebuild the grid on every scroll frame.
5. Use the system margins, not hard-coded padding. Apple's doc for `ContentMarginGuide.container` says the margins can be asymmetric on iPhone Duo next to a vertical bar.
6. Keep the reader's place when columns change. Anchor the scroll position to an item ID; see the `duo-continuity` skill.
7. Avoid extreme changes. A grid that goes from 2 to 6 columns and changes tile style at the same time is hard to follow ([HIG, Reserved regions](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions)).

## Recipe

Self-contained. Typechecks against the iOS 27.1 simulator SDK, also with an iOS 26 deployment target and with a new Xcode 27.1 app's main actor default isolation. `nonisolated` on `FeedGridInput` and `feedColumns` makes that last case work; see FoldGeometry in SKILL.md. We ran `feedColumns` on the Mac: for a 867 pt wide grid it returns 5 flexible columns with no fold, 4 with an inactive fold, and with an active fold from x = 435 to 475 it returns 213.5, 213.5, 192 and 192 pt columns whose widths and gaps add up to exactly 867.

```swift
import SwiftUI

/// What the grid needs to know, in the grid's own coordinate space.
/// Only x values are kept, so scrolling does not trigger a new layout.
nonisolated struct FeedGridInput: Equatable, Sendable {
    var width: CGFloat = 0
    /// Left and right edges of a top-to-bottom fold that crosses the grid, margins included.
    var foldMinX: CGFloat?
    var foldMaxX: CGFloat?
    var foldIsActive = false

    init() {}

    @available(iOS 27.1, *)
    init(_ proxy: GeometryProxy) {
        width = proxy.size.width
        let folds = proxy.reservedRegions(kind: .division, options: .includeInactive)
        guard let fold = folds.first(where: \.isActive) ?? folds.first else { return }
        let frame = fold.frame
        // Ignore a fold that runs side to side or misses the grid.
        guard frame.height > frame.width, frame.minX > 0, frame.maxX < width else { return }
        foldMinX = frame.minX
        foldMaxX = frame.maxX
        foldIsActive = fold.isActive
    }
}

/// Columns for a feed. Pure function: unit-test it on the Mac.
nonisolated func feedColumns(for input: FeedGridInput, minTileWidth: CGFloat, spacing: CGFloat) -> [GridItem] {
    guard input.width > 0 else { return [GridItem(.flexible(), spacing: spacing)] }
    var count = max(1, Int((input.width + spacing) / (minTileWidth + spacing)))
    // A fold crosses the grid (active or not): use an even count so it divides cleanly.
    if input.foldMinX != nil { count = max(2, count - count % 2) }

    guard input.foldIsActive, let minX = input.foldMinX, let maxX = input.foldMaxX else {
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
    }
    // Partly folded: half the columns on each side, and the fold as the middle gap.
    let half = count / 2
    let gaps = CGFloat(half - 1) * spacing
    let leftTile = (minX - gaps) / CGFloat(half)
    let rightTile = (input.width - maxX - gaps) / CGFloat(half)
    return (0..<count).map { index in
        let tile = index < half ? leftTile : rightTile
        let gapAfter = index == half - 1 ? maxX - minX : spacing
        return GridItem(.fixed(max(1, tile)), spacing: gapAfter)
    }
}

struct Photo: Identifiable {
    let id: Int
    var color: Color
}

@available(iOS 27.1, *)
struct PhotoFeed: View {
    let photos: [Photo]
    @State private var input = FeedGridInput()
    // Scales with Dynamic Type. A content size, not a screen size.
    @ScaledMetric(relativeTo: .body) private var minTileWidth = 150.0
    private let spacing: CGFloat = 8

    var body: some View {
        ScrollView {
            LazyVGrid(columns: feedColumns(for: input, minTileWidth: minTileWidth, spacing: spacing),
                      spacing: spacing) {
                ForEach(photos) { photo in
                    photo.color
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
            .onGeometryChange(for: FeedGridInput.self) { proxy in
                FeedGridInput(proxy)
            } action: { newInput in
                input = newInput
            }
            // System margins. They can differ per side next to a vertical bar.
            .contentMargins(for: .container, edges: .horizontal)
        }
    }
}
```

Why `onGeometryChange` sits on the grid, before the margins: the proxy then describes the grid's own box. The fold's frame comes back in that box's coordinates, so `foldMinX` is exactly the width the left columns may use.

## Pitfalls

- **Odd columns on the open phone.** Three or five columns put a tile in the curve when the phone folds.
- **Counting only active folds.** The default query returns only active regions. Flat, it returns nothing, so the grid shows 5 columns and then jumps to 4 when folded. Ask with `.includeInactive`.
- **Comparing full frames.** The grid scrolls, so region y values change all the time. Keep x values only.
- **`GridItem(.adaptive(minimum:))` alone.** It picks a count that fits, which is often odd. Compute the count yourself.
- **Moving the grid to one side when folded.** Feeds scroll; they don't displace.
- **Fixed tile sizes from a screenshot.** `150` here is a minimum tile width that scales with text size, not a screen width.

## Test it

1. Closed: count the columns. Open: the count is even.
2. Open, flat: tiles are equal width.
3. Partially Open: the middle gap sits exactly over the curve; outer margins stay the same.
4. Scroll fast while folded: no stutter from re-layout.
5. Largest Dynamic Type size: fewer, larger columns, still even when open.
6. Split View: as many columns as fit, odd is fine.

Duology has checked step 3 only in a still screenshot: in the gallery's [book shot](https://github.com/Kimeur/duology/blob/main/docs/assets/gallery/feedReflow-book.png) (18 October 2026) the middle gap runs from x 456 to 495.5 pt, over the fold region. Step 4 has not run. `simctl` has no pose command in Xcode 27.1, so set the pose in Device Hub.

## Gallery screen

[`samples/DuologyGallery/DuologyGallery/Patterns/FeedReflowView.swift`](https://github.com/Kimeur/duology/blob/main/samples/DuologyGallery/DuologyGallery/Patterns/FeedReflowView.swift)

## Sources

IDs point to [`reference/sources.md`](https://github.com/Kimeur/duology/blob/main/reference/sources.md): D2 (HIG), V3 (talk 111463), V6 (talk 111466), P2 (Android canonical layouts).
