# Grids, margins and the gutter at the fold

A layout grid for designed screens: dashboards, card collections, settings, product pages. It has an even number of columns in both size classes, the system margins on the outside, and the fold as its middle gutter when the phone is partly open.

For an endless feed that should show "as many tiles as fit", use the feed reflow pattern in `duo-patterns` ([feed-reflow.md](https://github.com/Kimeur/duology/blob/main/plugins/duology-design/skills/duo-patterns/references/feed-reflow.md)). Both follow the same fold rules.

## What Apple asks for

- Build layouts from layout margins and safe area insets, never fixed widths ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Dynamic-layouts), [111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=258)).
- Margins and safe areas are asymmetric on iPhone Duo. Content may come closer to a vertical bar while the other side keeps its margin ([111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=453)). [`ContentMarginGuide.container`](https://developer.apple.com/documentation/swiftui/contentmarginguide/container) gives these margins (16 to 20 pt on iPhone, per its doc).
- In a grid, prefer an even column count so content divides cleanly at the fold ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions)). Decide that whenever a division region exists, active or not ([111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=456)).
- To keep every grid item usable when the phone folds, keep the outer margins and widen the spacing around the hinge, so each item stays inside its half ([111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=350)).
- Make small adjustments, not rearrangements, as the phone folds ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions)).

## The grid in numbers

| | Outer display (compact) | Inner display, flat (regular) | Inner display, partly folded |
|---|---|---|---|
| Columns | 4 | 8 | 8, four per side |
| Gutter | 12 | 16 | 16, except the middle |
| Middle gutter | 12 | 16 | the fold's frame |
| Outer margins | system | system | system, unchanged |
| Card (span 2) per row | 2 | 4 | 4, two per side |
| Card at accessibility sizes (span 4) | 1 | 2 | 2, one per side |

Worked example. We ran `DuoColumns` (below) on these inputs on the iOS 27.1 simulator runtime:

- **Outer display.** The safe area is 382 pt wide in portrait (*measured* in `duo-setup`). With 16 pt margins on each side (*assumed*; Apple's range is 16 to 20 pt), the grid is 350 pt wide: four 78.5 pt columns, or two 169 pt cards.
- **Inner display, flat.** The safe area is 867 pt wide held wide, with the vertical bar on the right (*measured* in `duo-setup`). With 20 pt margins (*assumed*) the grid is 827 pt: eight 89.4 pt columns, or four 194.8 pt cards.
- **Inner display, partly folded.** `duo-layout` measured the fold's frame at x 455.5 to 495.5 in the window (flat, inactive). In the gallery's book-pose screenshot the gap that follows the active fold is about 40 pt too, so the width barely changes when folded. In the grid's coordinates that is 435.5 to 475.5. The left half gets four 96.9 pt columns and the right half four 75.9 pt columns. The halves differ because the vertical bar takes space on the right only. That is the asymmetry Apple's Fitness example accepts: outer margins stay, the middle widens.

Never put these numbers in code. They are here so you can check screenshots.

## The grid helper

Copy this next to `DuoTokens.swift`. It typechecks against the iOS 27.1 simulator SDK in Swift 5, Swift 6 and main actor default isolation modes, and with an iOS 17 deployment target. The checks in the worked example above ran against it.

```swift
import SwiftUI

/// A fold that runs top to bottom through a view, in that view's coordinates.
/// Only x values are kept, so scrolling never changes it.
nonisolated struct DuoFold: Equatable, Sendable {
    var minX: CGFloat
    var maxX: CGFloat
    var isActive: Bool

    init(minX: CGFloat, maxX: CGFloat, isActive: Bool) {
        self.minX = minX
        self.maxX = maxX
        self.isActive = isActive
    }

    /// The fold in `proxy`'s view, active or not. Nil on the outer display, when
    /// the fold runs side to side (held tall), or when it misses the view.
    @available(iOS 27.1, *)
    init?(_ proxy: GeometryProxy) {
        let folds = proxy.reservedRegions(kind: .division, options: .includeInactive)
        guard let fold = folds.first(where: \.isActive) ?? folds.first else { return nil }
        let frame = fold.frame
        guard frame.height > frame.width, frame.minX > 0, frame.maxX < proxy.size.width else {
            return nil
        }
        self.init(minX: frame.minX, maxX: frame.maxX, isActive: fold.isActive)
    }
}

/// What a grid needs to know about its own box. Equatable, so
/// `onGeometryChange` fires only when the width or the fold changes.
nonisolated struct DuoGridGeometry: Equatable, Sendable {
    var width: CGFloat = 0
    var fold: DuoFold?

    init() {}

    @available(iOS 27.1, *)
    init(_ proxy: GeometryProxy) {
        width = proxy.size.width
        fold = DuoFold(proxy)
    }
}

/// Column positions of a layout grid, in the grid's own coordinates.
nonisolated struct DuoColumns: Equatable, Sendable {
    struct Column: Equatable, Sendable {
        var x: CGFloat
        var width: CGFloat
        var maxX: CGFloat { x + width }
    }

    private(set) var columns: [Column]
    /// True when a fold crosses the grid, active or not. Groups never cross the middle then.
    private(set) var hasFold: Bool

    /// `count` is rounded down to even when a fold crosses the grid. While the
    /// fold is active, its frame is the middle gutter and each half gets half the columns.
    init(width: CGFloat, count: Int, gutter: CGFloat, fold: DuoFold? = nil) {
        var count = max(1, count)
        hasFold = fold != nil
        if hasFold { count = max(2, count - count % 2) }

        if let fold, fold.isActive {
            let half = count / 2
            let gaps = CGFloat(half - 1) * gutter
            let left = max(0, (fold.minX - gaps) / CGFloat(half))
            let right = max(0, (width - fold.maxX - gaps) / CGFloat(half))
            columns = (0..<count).map { index in
                index < half
                    ? Column(x: CGFloat(index) * (left + gutter), width: left)
                    : Column(x: fold.maxX + CGFloat(index - half) * (right + gutter), width: right)
            }
        } else {
            let each = max(0, (width - CGFloat(count - 1) * gutter) / CGFloat(count))
            columns = (0..<count).map { Column(x: CGFloat($0) * (each + gutter), width: each) }
        }
    }

    /// Merges every `span` columns into one. With a fold, each half is grouped
    /// on its own, so no group crosses the middle gutter.
    func grouped(by span: Int) -> DuoColumns {
        let span = max(1, span)
        guard span > 1, !columns.isEmpty else { return self }
        let middle = columns.count / 2
        let halves = hasFold ? [columns[..<middle], columns[middle...]] : [columns[...]]
        var merged: [Column] = []
        for half in halves {
            var start = half.startIndex
            while start < half.endIndex {
                let last = min(start + span, half.endIndex) - 1
                merged.append(Column(x: half[start].x, width: half[last].maxX - half[start].x))
                start += span
            }
        }
        var result = self
        result.columns = merged
        return result
    }

    /// Items for `LazyVGrid`: fixed widths, and the real gap after each column.
    var gridItems: [GridItem] {
        guard let first = columns.first, first.width > 0 else {
            return Array(repeating: GridItem(.flexible()), count: max(1, columns.count))
        }
        return columns.indices.map { index in
            let next = index + 1 < columns.count ? columns[index + 1].x : columns[index].maxX
            return GridItem(.fixed(columns[index].width), spacing: next - columns[index].maxX)
        }
    }
}
```

How it behaves:

| Situation | `fold` | Columns |
|---|---|---|
| Outer display, any orientation | `nil` | `count` equal columns; groups may span the full width |
| Inner display, held tall (fold runs across) | `nil` | equal columns; the fold falls between rows |
| Inner display, flat, held wide | inactive | even count, equal columns; groups stay in their half |
| Inner display, partly folded | active | even count; the fold's frame is the middle gap |
| A pane that the fold misses, or that the fold only touches at its edge (Split View, not measured) | `nil` | `count` equal columns |

Flat, the middle gutter is a normal gutter, not the fold's 40 pt frame. When the phone folds, only that one gap grows and the columns beside it narrow. Nothing changes row or order. That keeps the change small, as the HIG asks. If your screen must not move at all when it folds (a two-page spread, a board game), reserve the fold's frame even when flat: pass `DuoFold(minX:maxX:isActive: true)` built from the inactive frame. That is a Duology option, not an Apple rule.

## A card grid

`DuoCard` comes from [tokens.md](tokens.md). The geometry reader sits on the grid, before the margins, so the fold comes back in the grid's own coordinates.

```swift
import SwiftUI

// requires: DuoTokens.swift, DuoColumns.swift

struct Item: Identifiable {
    let id: Int
    var title: String
}

@available(iOS 27.1, *)
struct CardGrid: View {
    let items: [Item]
    @DuoMetrics private var tokens
    @State private var geometry = DuoGridGeometry()

    var body: some View {
        let columns = DuoColumns(width: geometry.width, count: tokens.columns,
                                 gutter: tokens.gutter, fold: geometry.fold)
            .grouped(by: tokens.span(2))
        ScrollView {
            LazyVGrid(columns: columns.gridItems, alignment: .leading, spacing: tokens.gutter) {
                ForEach(items) { item in
                    DuoCard { Text(item.title).font(DuoType.itemTitle) }
                }
            }
            .onGeometryChange(for: DuoGridGeometry.self) { proxy in
                DuoGridGeometry(proxy)
            } action: { newValue in
                geometry = newValue
            }
            .duoContainerMargins()
        }
    }
}

/// The same grid for code that also runs below iOS 27.1. No fold awareness there,
/// and iPhone Duo always runs iOS 27.1, so call CardGrid inside `if #available`.
struct CardGridAnyOS: View {
    let items: [Item]
    @DuoMetrics private var tokens
    @State private var width: CGFloat = 0

    var body: some View {
        let columns = DuoColumns(width: width, count: tokens.columns, gutter: tokens.gutter)
            .grouped(by: tokens.span(2))
        ScrollView {
            LazyVGrid(columns: columns.gridItems, alignment: .leading, spacing: tokens.gutter) {
                ForEach(items) { item in
                    DuoCard { Text(item.title).font(DuoType.itemTitle) }
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .duoContainerMargins()
        }
    }
}
```

## Spans

Give each kind of content a span, not a width:

| Content | Span (`tokens.span(n)`) | Outer display | Inner display |
|---|---|---|---|
| Thumbnail, photo tile | 1 | 4 per row | 8 per row |
| Card with a title and a line of text | 2 | 2 per row | 4 per row |
| Wide card, chart, form section | 4 | 1 per row | 2 per row, one per side |

`span(_:)` doubles at accessibility text sizes, so cards get wider as the text grows. With a fold, a group never crosses the middle, so a span of 8 still gives one card per side. Put content that must run the full width (a hero image, a header) outside the grid.

## Pitfalls

- **Odd column counts on the inner display.** A tile lands in the curve when the phone folds.
- **Counting only active folds.** Flat, the default query returns nothing, so a grid picks 5 columns, then jumps to 4 when folded. `DuoFold` asks with `.includeInactive`.
- **Centring the grid on the full window.** The vertical bar takes one side, so the fold is not at the centre of the safe area. `DuoColumns` places the middle gap at the fold's own x values.
- **Equal halves when folded.** Forcing both halves to the same width moves the outer margins or pushes tiles into the fold. Let the halves differ.
- **Fixed padding instead of margins.** `.padding(.horizontal, 20)` ignores the asymmetric margins next to a vertical bar.
- **Using a custom split's size class.** An `EvenSplit` half from `duo-layout` keeps the window's regular width class even at a third of the width. Set `.environment(\.horizontalSizeClass, .compact)` on each half so it gets the 4-column grid.

## Test it

1. Closed: 4 columns, the same margins on both sides of the content.
2. Open, flat, held wide: 8 columns, equal widths; in Split View on either side, 4 or 8 columns with the margins on the correct sides.
3. Partially Open in Device Hub: the middle gap sits over the curve; outer margins unchanged; no card crosses the gap.
4. Open, held tall: the fold runs between rows; columns unchanged.
5. AX5 text size: cards widen to the next span; still nothing in the fold.

`simctl` cannot change the pose. Use the pose buttons in Device Hub.
