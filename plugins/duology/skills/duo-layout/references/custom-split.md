# Custom splits

When `ArrangementView` is the wrong tool, and how to fit content into a half.

Everything on this page except `DuelOnTheFold` typechecks at an iOS 17 deployment target. `DuelOnTheFold` reads reserved regions, so it is marked `@available(iOS 27.1, *)` ([SKILL.md](../SKILL.md#deploying-below-ios-271)).

## Pick the container

| You need | Use |
|---|---|
| A hierarchy (list, then detail) that collapses to one column when closed | `NavigationSplitView` (see `duo-navigation`) |
| Two related views; showing only the primary in tight spaces is fine | `ArrangementView` ([arrangement-view.md](arrangement-view.md)) |
| Two equal halves that show in **every** pose, closed and sideways included | `EvenSplit` |
| Two halves that show in every pose, with the seam exactly on an active fold | `FoldSplitLayout` |

Why not `ArrangementView` for the last two: closed and held sideways, the phone is compact width and compact height, and a split arrangement then shows only its primary view (*measured*, see [arrangement-view.md](arrangement-view.md#what-we-measured)). A second player, a second page or a shared board would vanish.

## EvenSplit

This is the same type as the gallery app's [`samples/DuologyGallery/DuologyGallery/Shared/EvenSplit.swift`](https://github.com/Kimeur/duology/blob/main/samples/DuologyGallery/DuologyGallery/Shared/EvenSplit.swift).

```swift
import SwiftUI

/// Two equal halves that always show. Side by side when the view is wider
/// than tall, stacked otherwise. AnyLayout keeps each half's state when the
/// axis flips.
struct EvenSplit<Primary: View, Secondary: View>: View {
    var spacing: CGFloat = 0
    @ViewBuilder var primary: () -> Primary
    @ViewBuilder var secondary: () -> Secondary

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= proxy.size.height
            let half = wide
                ? CGSize(width: max(0, (proxy.size.width - spacing) / 2), height: proxy.size.height)
                : CGSize(width: proxy.size.width, height: max(0, (proxy.size.height - spacing) / 2))
            let layout = wide
                ? AnyLayout(HStackLayout(spacing: spacing))
                : AnyLayout(VStackLayout(spacing: spacing))
            layout {
                primary().frame(width: half.width, height: half.height)
                secondary().frame(width: half.width, height: half.height)
            }
        }
    }
}
```

Why it is built this way:

- **Aspect, not size class.** The axis follows the view's own shape, so it is right on both displays, in Split View and in any window size.
- **`AnyLayout`, not `if wide { HStack } else { VStack }`.** An `if` gives the halves a new identity when the axis flips, so a game board, a scroll position or a text field resets on every rotation or fold. `AnyLayout` keeps them ([AnyLayout](https://developer.apple.com/documentation/swiftui/anylayout)). *Measured:* flipping this `EvenSplit` from 678 × 466 to 466 × 640 kept each half's `@State` and ran no `onDisappear`.
- **Exact half frames.** Each half gets exactly half the space, whatever its content asks for, so a wide label can't push the seam.
- **Size classes don't change.** Each half keeps the window's size classes. *Measured:* a 338 pt half on the inner display read regular width and regular height. Lay out inside a half by its size (the next sections), not by its size class. `ArrangementView` is different: it gives each half its own classes.
- **`spacing`** leaves a gap. Put a colour behind the split to draw a divider: `EvenSplit(spacing: 2) { ... }.background(Color.secondary)`.

`EvenSplit` puts its seam at the middle of its own frame. On a flat phone that does not matter. On a partly folded phone, the seam only lands on the fold if `EvenSplit` is centred on the display. A vertical bar on one side moves the centre. When the seam must sit on the fold, use `FoldSplitLayout`.

## Two people, two halves

```swift
import SwiftUI

struct FaceOffScreen: View {
    var body: some View {
        EvenSplit(spacing: 2) {
            PlayerHalf(player: 1)
        } secondary: {
            PlayerHalf(player: 2)
        }
        .background(Color.secondary)
        .persistentSystemOverlays(.hidden)
    }
}

struct PlayerHalf: View {
    let player: Int
    @State private var lastTouch: CGPoint?

    private var space: NamedCoordinateSpace { .named("half-\(player)") }

    var body: some View {
        ZStack {
            Color(.systemBackground)
            if let lastTouch {
                Circle().frame(width: 44, height: 44).position(lastTouch)
            }
        }
        .coordinateSpace(space)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 6, coordinateSpace: space)
                .onChanged { lastTouch = $0.location }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Player \(player)")
    }
}
```

- Give each half its own named coordinate space and read touch locations in it. Then the same game code works whichever half it is in, and whichever axis the split uses.
- Clip each half, so a drag or a drawing never spills into the other player's side.
- Put shared controls (pause, leave) in one place only, away from the seam.
- `persistentSystemOverlays(.hidden)` keeps the home indicator out of play.
- Device Hub can't send two touches at once (Xcode 27 known issue, [release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)). Test two people playing together on a device.

More on shared-screen design: `duo-shared-screen`.

## Try both arrangements, keep the bigger

A half changes shape a lot: tall and narrow, short and wide, about 382 × 321 pt inside the safe area when the phone is closed and portrait (*measured* in `duo-shared-screen`). One fixed arrangement inside the half will waste space in some of those shapes. Instead, compute each candidate layout for the current size, score it by the size of its smallest important element, and keep the best.

```swift
import SwiftUI

/// Where the tray goes inside one half, and how big a board cell can be.
struct BoardPlan: Equatable {
    var trayBeside: Bool
    var cell: CGFloat

    /// Lays the half out both ways and keeps whichever gives bigger cells.
    static func best(in size: CGSize, columns: Int, rows: Int,
                     trayShare: CGFloat = 0.35, gap: CGFloat = 12) -> BoardPlan {
        let below = BoardPlan(
            trayBeside: false,
            cell: min(size.width / CGFloat(columns),
                      (size.height - gap) * (1 - trayShare) / CGFloat(rows))
        )
        let beside = BoardPlan(
            trayBeside: true,
            cell: min((size.width - gap) * (1 - trayShare) / CGFloat(columns),
                      size.height / CGFloat(rows))
        )
        return beside.cell > below.cell ? beside : below
    }
}

struct BoardHalf: View {
    let columns = 6
    let rows = 6

    var body: some View {
        GeometryReader { proxy in
            let plan = BoardPlan.best(in: proxy.size, columns: columns, rows: rows)
            let layout = plan.trayBeside
                ? AnyLayout(HStackLayout(spacing: 12))
                : AnyLayout(VStackLayout(spacing: 12))
            layout {
                BoardGrid(columns: columns, rows: rows, cell: plan.cell)
                PieceTray()
            }
        }
    }
}
```

- Score with what people need to see and hit. If the tray pieces matter as much as the board, score `min(boardCell, trayCell)`.
- Keep the plan a plain value type. You can unit test `best(in:...)` on the Mac with sizes from every pose.
- `AnyLayout` again keeps the board and tray alive when the plan flips.

## Thresholds for small halves

Pick thresholds from your content, not from a device. Measure the height your full layout needs and switch below it. For scale: closed and portrait, a stacked half is about 382 × 321 pt inside the safe area (*measured* in `duo-shared-screen`; 466 × 339 pt if the split ignores the safe area). In order:

1. Drop decorative labels and captions.
2. Tighten spacing.
3. Switch text buttons to icon buttons, with accessibility labels.
4. Never shrink touch targets below 44 pt, and never drop a feature.

`ViewThatFits` handles the simple case. It picks the first variant that fits:

```swift
import SwiftUI

struct HalfToolbar: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                Label("Undo", systemImage: "arrow.uturn.backward")
                Label("Hint", systemImage: "lightbulb")
                Label("Restart", systemImage: "arrow.clockwise")
            }
            HStack(spacing: 12) {
                Image(systemName: "arrow.uturn.backward").accessibilityLabel("Undo")
                Image(systemName: "lightbulb").accessibilityLabel("Hint")
                Image(systemName: "arrow.clockwise").accessibilityLabel("Restart")
            }
        }
        .font(.title3)
    }
}
```

For finer control, read the size once and derive a flag:

```swift
import SwiftUI

struct ScorePanel: View {
    let score: Int
    let onPass: () -> Void
    @State private var isTight = false

    var body: some View {
        VStack(spacing: isTight ? 4 : 12) {
            Text(score, format: .number)
                .font(isTight ? .title2 : .largeTitle)
                .monospacedDigit()
            if !isTight {
                Text("Points").foregroundStyle(.secondary)
            }
            Button("Pass", action: onPass)
                .buttonStyle(.borderedProminent)
                .controlSize(isTight ? .regular : .large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.height < 360
        } action: { tight in
            isTight = tight
        }
    }
}
```

The 360 pt here is this panel's own need. Yours will differ.

## Put the seam on the fold

`FoldSplitLayout` splits at the active fold when there is one, and in the middle otherwise. It keeps the fold's whole frame, margins included, as the gap. It is one `Layout` type whatever the fold does, so the halves keep their identity.

```swift
import SwiftUI

/// Two views split at the active fold, or in the middle when there is none.
/// `fold` is the active division's frame in this view's own coordinates.
struct FoldSplitLayout: Layout {
    var fold: CGRect?
    var spacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let wide = bounds.width >= bounds.height
        var cut = wide ? bounds.midX : bounds.midY
        var gap = spacing
        if let fold {
            let foldRunsTopToBottom = fold.height > fold.width
            if wide && foldRunsTopToBottom {
                cut = bounds.minX + fold.midX
                gap = max(spacing, fold.width)
            } else if !wide && !foldRunsTopToBottom {
                cut = bounds.minY + fold.midY
                gap = max(spacing, fold.height)
            }
        }
        let first: CGRect
        let second: CGRect
        if wide {
            first = CGRect(x: bounds.minX, y: bounds.minY,
                           width: max(0, cut - gap / 2 - bounds.minX), height: bounds.height)
            second = CGRect(x: cut + gap / 2, y: bounds.minY,
                            width: max(0, bounds.maxX - cut - gap / 2), height: bounds.height)
        } else {
            first = CGRect(x: bounds.minX, y: bounds.minY,
                           width: bounds.width, height: max(0, cut - gap / 2 - bounds.minY))
            second = CGRect(x: bounds.minX, y: cut + gap / 2,
                            width: bounds.width, height: max(0, bounds.maxY - cut - gap / 2))
        }
        subviews[0].place(at: first.origin, proposal: ProposedViewSize(first.size))
        subviews[1].place(at: second.origin, proposal: ProposedViewSize(second.size))
    }
}

@available(iOS 27.1, *)
struct DuelOnTheFold: View {
    @State private var fold: CGRect?

    var body: some View {
        FoldSplitLayout(fold: fold, spacing: 2) {
            PlayerHalf(player: 1)
            PlayerHalf(player: 2)
        }
        .onGeometryChange(for: CGRect?.self) { proxy in
            proxy.reservedRegions(kind: .division).first(where: \.isActive)?.frame
        } action: { newFold in
            fold = newFold
        }
    }
}
```

- The fold frame comes from the same view that uses the layout, so its coordinates match `bounds`.
- Right-to-left needs no extra code: a `Layout` flips the subviews it places, and SwiftUI mirrors region frames to match ([ReservedRegion](https://developer.apple.com/documentation/swiftui/reservedregion)).
- *Measured:* in our probe, with no fold the halves came out 474.5 pt each with a 2 pt gap in a 951 pt view. With a fold frame passed in by hand (x 455, 40 pt wide), they came out 0–455 and 495–951. It has not yet run with a real active fold, on a device or a folded simulator. (unverified)

## Test a split

- Closed, portrait: stacked halves.
- Closed, sideways: side-by-side halves. This is the pose where `ArrangementView` would show one half.
- Open, wide and tall.
- Partly open: seam on the fold, nothing tappable in the division frame.
- Split View on each side.
- Rotate and fold while dragging: the game state must survive (see `duo-continuity`).
