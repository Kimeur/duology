# Grids, margins and the gutter at the fold

A layout grid for designed screens: dashboards, card collections, settings, product pages. It has an even number of columns in both size classes, the system margins on the outside, and the fold in its middle gutter: a normal gutter on the fold line when the phone is flat, the fold's frame when it is partly open.

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
| Columns | 4 | 8, four per side of the fold | 8, four per side |
| Gutter | 12 | 16 | 16, except the middle |
| Middle gutter | 12 | 16, centred on the fold line | the fold's frame |
| Outer margins | system, per side | system, per side | system, unchanged |
| Card (span 2) per row | 2 | 4, two per side | 4, two per side |
| Card at accessibility sizes (span 4) | 1 | 2, one per side | 2, one per side |

Worked example. We ran `DuoColumns` (below) on these inputs on the iOS 27.1 simulator runtime, and checked that a `LazyVGrid` built from it puts every item on its column:

- **Outer display.** The safe area is 382 pt wide in portrait (*measured* in `duo-setup`). With 16 pt margins on each side (*assumed*; Apple's range is 16 to 20 pt, and the margin next to the status bar column can be smaller), the grid is 350 pt wide: four 78.5 pt columns, or two 169 pt cards.
- **Inner display, flat.** The safe area is 867 pt wide held wide, with the vertical bar on the right (*measured* in `duo-setup`). With 20 pt margins (*assumed*) the grid is 827 pt. `duo-layout` measured the flat fold's frame at x 455.5 to 495.5 in the window: a line at x 475.5 plus 20 pt on each side. In the grid's coordinates that is 435.5 to 475.5, with the line at 455.5. The middle gutter (16 pt) sits on that line, so the left half gets four 99.9 pt columns and the right half four 78.9 pt columns: cards of 215.8 and 173.8 pt.
- **Inner display, partly folded.** The gallery app's region overlay reports the active fold as 40 × 669 pt at x 455 in a 951 pt window ([screenshot](https://github.com/Kimeur/duology/blob/main/docs/assets/gallery/regions-book.png)), so the frame keeps its width when the phone folds. The middle gap grows from 16 to 40 pt: the left columns narrow to 96.9 pt and the right ones to 75.9 pt (cards of 209.8 and 167.8 pt). No column edge moves more than 12 pt.
- **Why the halves differ.** The vertical bar takes space on the right only, so the fold is 42 pt right of the grid's centre. That is the asymmetry Apple's Fitness example accepts: outer margins stay, the middle widens.
- **A half of an `EvenSplit(spacing: 2)`** (`duo-layout`) with compact tokens. The right half starts at x 434.5; with 16 pt margins its grid is 400.5 pt wide and the fold runs through it at x 5 to 45, too close to its leading edge for two columns. All four columns go after the fold: flat from x 31 (83.4 pt each), partly folded from x 45 (79.9 pt each). The left half doesn't meet the fold at all.

Never put these numbers in code. They are here so you can check screenshots.

## The grid helper

Copy this next to `DuoTokens.swift`. It typechecks against the iOS 27.1 simulator SDK in Swift 5, Swift 6 and main actor default isolation modes, and with an iOS 17 deployment target. The worked example above and the resize check under [A card grid](#a-card-grid) ran against it.

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
    /// Index of the first column after the fold, or nil when the fold doesn't
    /// split the grid. Groups never cross it.
    private(set) var split: Int?

    /// With a fold, `count` is rounded down to even and each side of the fold gets
    /// half the columns. Flat, the gap at the fold is one gutter centred on it;
    /// partly folded, it is the fold's frame. If one side is too narrow for its
    /// half at `minimumColumn`, every column goes on the other side and the fold
    /// becomes the grid's edge.
    init(width: CGFloat, count: Int, gutter: CGFloat, fold: DuoFold? = nil,
         minimumColumn: CGFloat = 44) {
        guard let fold else {
            columns = Self.row(from: 0, to: width, count: max(1, count), gutter: gutter)
            split = nil
            return
        }
        let count = max(2, count - count % 2)
        let half = count / 2
        let gapStart = fold.isActive ? fold.minX : (fold.minX + fold.maxX - gutter) / 2
        let gapEnd = fold.isActive ? fold.maxX : gapStart + gutter
        // Decided on the fold's frame, which has the same size flat and folded,
        // so the choice doesn't flip when the phone folds.
        func holdsHalf(_ length: CGFloat) -> Bool {
            length - CGFloat(half - 1) * gutter >= CGFloat(half) * minimumColumn
        }
        if holdsHalf(fold.minX), holdsHalf(width - fold.maxX) {
            columns = Self.row(from: 0, to: gapStart, count: half, gutter: gutter)
                + Self.row(from: gapEnd, to: width, count: half, gutter: gutter)
            split = half
        } else if fold.minX > width - fold.maxX {
            columns = Self.row(from: 0, to: gapStart, count: count, gutter: gutter)
            split = nil
        } else {
            columns = Self.row(from: gapEnd, to: width, count: count, gutter: gutter)
            split = nil
        }
    }

    private static func row(from start: CGFloat, to end: CGFloat,
                            count: Int, gutter: CGFloat) -> [Column] {
        let each = max(0, (end - start - CGFloat(count - 1) * gutter) / CGFloat(count))
        return (0..<count).map { Column(x: start + CGFloat($0) * (each + gutter), width: each) }
    }

    /// Merges every `span` columns into one. Each side of the fold is grouped
    /// on its own, so no group crosses it.
    func grouped(by span: Int) -> DuoColumns {
        let span = max(1, span)
        guard span > 1, !columns.isEmpty else { return self }
        let sides = split.map { [columns[..<$0], columns[$0...]] } ?? [columns[...]]
        var result = self
        result.columns = []
        for (index, side) in sides.enumerated() {
            if index == 1 { result.split = result.columns.count }
            var start = side.startIndex
            while start < side.endIndex {
                let last = min(start + span, side.endIndex) - 1
                result.columns.append(Column(x: side[start].x, width: side[last].maxX - side[start].x))
                start += span
            }
        }
        return result
    }

    /// Empty space before the first column. Not zero only when the fold is the
    /// grid's leading edge. Put it on the grid as leading padding.
    var leadingInset: CGFloat { columns.first?.x ?? 0 }

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
| Inner display, flat, held wide | inactive | even count, half on each side; one normal gutter centred on the fold line; groups stay in their half |
| Inner display, partly folded | active | even count, half on each side; the fold's frame is the middle gap |
| A pane where one side of the fold can't hold half the columns at 44 pt (an `EvenSplit` half) | either | every column on the wider side; the fold becomes the grid's edge, and `leadingInset` says how far in the grid starts |
| A pane that the fold misses, or that the fold only touches at its edge (Split View, not measured) | `nil` | `count` equal columns |

Flat, the gap at the fold is a normal gutter, centred on the fold line. When the phone folds, only that one gap grows, to the fold's frame, and the columns beside it narrow by a few points. Nothing changes row or order. That keeps the change small, as the HIG asks. The cost: flat, the two halves differ in width when a vertical bar sits on one side. If your screen must not move at all when it folds (a two-page spread, a board game), reserve the fold's frame even when flat: pass `DuoFold(minX:maxX:isActive: true)` built from the inactive frame. That is a Duology option, not an Apple rule.

## A card grid

`DuoCard` comes from [tokens.md](tokens.md). The geometry reader sits on a frame around the grid, before the margins, so the fold comes back in the grid's own coordinates. Three lines matter:

- `.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)` before `onGeometryChange`. A `LazyVGrid` with fixed columns is as wide as its columns, not as wide as the space it gets. Measured on it directly, the width never shrinks: the grid stayed 827 pt wide in a 350 pt window (*measured*). `.frame(maxWidth: .infinity)` alone kept the bug (*measured*); the `minWidth: 0` is what lets the frame shrink.
- `.padding(.leading, columns.leadingInset)`, for the case where every column sits after the fold.
- `.background(DuoColor.groupedBackground)`. `DuoCard` is white in light mode, the same white as `DuoColor.background`, so it needs the grouped grey behind it to show an edge.

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
            .padding(.leading, columns.leadingInset)
            // Take the offered width, not the sum of the fixed columns,
            // so the measured width also shrinks when the window does.
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: DuoGridGeometry.self) { proxy in
                DuoGridGeometry(proxy)
            } action: { newValue in
                geometry = newValue
            }
            .duoContainerMargins()
        }
        .background(DuoColor.groupedBackground)
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
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .duoContainerMargins()
        }
        .background(DuoColor.groupedBackground)
    }
}
```

*Measured* headless on the iOS 27.1 simulator runtime: both views hosted in a window, resized 827 → 350 → 827 → 350 → 867 pt with the size class switched to match. The scroll view and its content followed every width in both directions. Before the frame line was added, both stayed at 827 pt after the first shrink and stuck out of the window. A `LazyVGrid` built from the worked example's columns (flat, folded, the `EvenSplit` half, and a fold near the trailing edge) put every item within 0.5 pt of its column.

## Spans

Give each kind of content a span, not a width:

| Content | Span (`tokens.span(n)`) | Outer display | Inner display |
|---|---|---|---|
| Thumbnail, photo tile | 1 | 4 per row | 8 per row |
| Card with a title and a line of text | 2 | 2 per row | 4 per row |
| Wide card, chart, form section | 4 | 1 per row | 2 per row, one per side |

`span(_:)` doubles at accessibility text sizes, so cards get wider as the text grows. With a fold, a group never crosses the middle, so a span of 8 still gives one card per side. Put content that must run the full width (a hero image, a header) outside the grid.

## Pitfalls

- **Reading the width from a grid with fixed columns.** It reports the sum of its columns, so it never shrinks when the phone closes, rotates or enters Split View. Measure a frame that fills the offered width, as `CardGrid` does.
- **Odd column counts on the inner display.** A tile lands in the curve when the phone folds.
- **Counting only active folds.** Flat, the default query returns nothing, so a grid picks 5 columns, then jumps to 4 when folded. `DuoFold` asks with `.includeInactive`.
- **Centring the grid on the full window.** The vertical bar takes one side, so the fold is not at the centre of the safe area. `DuoColumns` places the middle gap at the fold's own x values, flat and folded.
- **Equal halves when folded.** Forcing both halves to the same width moves the outer margins or pushes tiles into the fold. Let the halves differ.
- **Fixed padding instead of margins.** `.padding(.horizontal, 20)` ignores the asymmetric margins next to a vertical bar.
- **Using a custom split's size class.** An `EvenSplit` half from `duo-layout` keeps the window's regular width class even at a third of the width. Set `.environment(\.horizontalSizeClass, .compact)` on each half so it gets the 4-column grid. The fold can then cross a half near its edge; `DuoColumns` moves every column to the wider side instead of making 5 pt columns.

## Test it

1. Closed: 4 columns. The leading and trailing margins may differ next to the status bar column; both must come from `duoContainerMargins()`.
2. Open, flat, held wide: 8 columns, four on each side of the fold line, with one normal gutter on the line. The halves can differ in width next to the vertical bar. In Split View on either side, 4 or 8 columns with the margins on the correct sides.
3. Partially Open in Device Hub: the middle gap sits over the curve; outer margins unchanged; no card crosses the gap; columns narrow a little but keep their row and order.
4. Open, held tall: the fold runs between rows; columns unchanged.
5. AX5 text size: cards widen to the next span; still nothing in the fold.
6. Close, open, close again, then enter and leave Split View: the grid follows the window both ways and nothing sticks out past the margins.

`simctl` cannot change the pose. Use the pose buttons in Device Hub. Steps 1 to 5 have not run on the Duo simulator with this helper; step 6 ran headless only (above).
