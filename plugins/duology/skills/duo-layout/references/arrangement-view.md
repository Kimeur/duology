# ArrangementView

A system layout container for two views, new in iOS 27.1. It sits between navigation containers (`NavigationStack`, `TabView`) and content containers (`List`, `ScrollView`).

Apple sources: [ArrangementView](https://developer.apple.com/documentation/swiftui/arrangementview), [arrangementViewStyle(_:)](https://developer.apple.com/documentation/swiftui/view/arrangementviewstyle(_:)), [UIArrangementViewController](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller), [overview: Arrange views in different poses](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo), [HIG: Arrangement views](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Arrangement-views), [Tech Talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=560).

## What it decides

The talk describes an arrangement as a function. Inputs: the size classes, the view's aspect ratio and any active division. Outputs: whether each view shows, and its frame. You give it a primary and a secondary view and pick a style.

| Style | Spelling | Flat | Partly folded | Use instead of |
|---|---|---|---|---|
| Automatic | `.automatic` | resolves to split | resolves to split | — |
| Split | `.split`, `.split.axes(_:)` | side by side when wider than tall, stacked when taller | each view on its own side of the fold | `HStack`, `VStack` |
| Overlay | `.overlay`, `.overlay.axes(_:)` | primary layered on top of secondary | side by side: primary on the trailing or bottom side, secondary on the leading or top side | `ZStack` |

Pick by relationship ([111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=879)):

- Main content plus detail that must never be covered (a player and its transcript): split.
- Foreground over background where partial cover is fine (controls over scrollable text or video): overlay.

## What we measured

Probe on the iPhone Duo simulator, iOS 27.1, inner display fully open. We put an `ArrangementView` in a fixed frame and overrode `horizontalSizeClass` and `verticalSizeClass` in the environment to stand in for other poses. We logged each half's frame and checked with a hit test which half was really on screen.

| Frame (pt) | Width / height class | Style | Result |
|---|---|---|---|
| 678 × 466 | compact / compact | `.automatic`, `.split` | **primary only**; secondary never drawn |
| 678 × 466 | compact / compact | `.overlay` | both full size, primary on top |
| 678 × 466 | compact / regular | `.automatic` | stacked, 678 × 233 each |
| 678 × 466 | regular / compact | `.automatic` | side by side, 339 × 466 each |
| 678 × 466 | regular / regular | `.automatic` | side by side, 339 × 466 each |
| 466 × 660 | compact / regular | `.automatic` | stacked, 466 × 330 each |
| 466 × 660 | compact / regular | `.split.axes(.horizontal)` | primary only |
| 466 × 660 | regular / regular | `.automatic` | stacked, 466 × 330 each |
| 669 × 660 | regular / regular | `.automatic` | side by side, 334.5 each |
| 951 × 669 | inherited (regular / regular) | `.automatic`, `.split` | side by side, 475.5 each |
| 951 × 669 | inherited (regular / regular) | `.overlay` | both full size, primary on top |

The first run logged whole points, rounded down. A rerun with half points printed 334.5 pt halves for the 669 pt frame; 475.5 is the same arithmetic for 951.

Our reading of these cases (not a rule Apple documents): side by side needs a regular width class, stacked needs a regular height class, and when both are possible the aspect ratio decides. With compact width and compact height, split shows the primary view alone.

What it means on the device:

- **Closed, held sideways** (outer display, compact / compact): a split arrangement shows only the primary view. A two-player app tested on the iOS 27.1 simulator in that pose showed the same thing. Fine for a player plus "up next". Wrong when both halves must show: use [EvenSplit](custom-split.md).
- **Closed, portrait** (compact / regular): the two views stack, roughly 382 × 322 pt each inside the safe area (*derived* from the 382 × 644 pt safe area that `duo-design-review` measured in the 466 × 678 pt window; 466 × 339 pt if the arrangement ignores the safe area).
- **Open**: side by side when wide, stacked when tall.
- **The hidden view still runs `onAppear`.** Don't use `onAppear` to learn whether the secondary is visible.
- **Each half gets its own size classes.** Side by side on the inner display, a half read compact width and regular height. Stacked halves in a compact / regular frame read compact / compact. Overlay halves kept the parent's classes. Design each half for the class it actually gets.

Not measured: real folding (division active), and the outer display itself. The size classes were overridden, not produced by a real closed phone.

## Read arrangement values one level down

`splitArrangementAxis` (`Axis?`) and `overlayArrangementZIndex` (`Int`) tell a half how it is placed. *Measured:* when the view you pass to `ArrangementView` read them through its own `@Environment`, it got the defaults (`nil`, `0`) and the parent's size classes, even while the split was active. A view nested inside it got the right values (`horizontal`, `1` for the overlaid primary). A `ZStack` wrapper worked; `Group` did not. Apple's talk reads the value in the view it passes in, so retest this on your setup, but write it the nested way.

```swift
import SwiftUI

@available(iOS 27.1, *)
struct PodcastScreen: View {
    var body: some View {
        NavigationStack {
            ArrangementView {
                ZStack { UpNextPanel() }
            } secondary: {
                EpisodePlayer()
            }
            .arrangementViewStyle(.overlay)
        }
    }
}

/// Collapses while it floats over the player; expands when the fold puts it beside the player.
@available(iOS 27.1, *)
struct UpNextPanel: View {
    @Environment(\.overlayArrangementZIndex) private var zIndex

    var body: some View {
        UpNextList(collapsed: zIndex > 0)
    }
}
```

The same pattern for the split axis. Inside a side-by-side half, stack the details; inside a stacked half, put them in a row.

```swift
import SwiftUI

@available(iOS 27.1, *)
struct EpisodeDetailsHalf: View {
    var body: some View {
        ZStack { EpisodeDetails() }
    }
}

@available(iOS 27.1, *)
struct EpisodeDetails: View {
    @Environment(\.splitArrangementAxis) private var axis

    var body: some View {
        let layout = axis == .vertical
            ? AnyLayout(HStackLayout(spacing: 16))
            : AnyLayout(VStackLayout(spacing: 12))
        layout {
            Artwork()
            EpisodeMetadata()
        }
    }
}
```

## Sizing the halves

All of these go on the primary or secondary view, and only affect `.split`:

| Modifier | Effect |
|---|---|
| `splitArrangementLayoutRatio(_:)` | preferred share of the container, for example `0.3` |
| `splitArrangementLayoutRatio(minHorizontal:idealHorizontal:maxHorizontal:minVertical:idealVertical:maxVertical:)` | separate ranges for side-by-side and stacked |
| `splitArrangementLayoutSize(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:)` | point limits; width applies side by side, height applies stacked |
| `splitArrangementFixedLayoutSize(horizontal:vertical:)` | prefer the view's ideal size on the chosen axes |

Apple's docs say the view with the higher `layoutPriority` is sized first. If the ratios leave space over, that same view takes it.

```swift
import SwiftUI

@available(iOS 27.1, *)
struct ChatWithPhotos: View {
    var body: some View {
        ArrangementView {
            ConversationList()
                .splitArrangementLayoutRatio(minHorizontal: 0.3, idealHorizontal: 0.4, maxHorizontal: 0.5)
        } secondary: {
            PhotoBrowser()
        }
        .arrangementViewStyle(.split.axes(.horizontal))
    }
}
```

With `.axes(.horizontal)` and a tall view, only the primary shows. Make sure the primary alone is a complete screen.

For overlay, `overlayArrangementEdge(_:)` picks the side a view moves to when the overlay turns into a side-by-side layout. It takes a `HorizontalEdge?` or a `VerticalEdge?`.

```swift
import SwiftUI

@available(iOS 27.1, *)
struct ReaderWithControls: View {
    var body: some View {
        ArrangementView {
            ReaderControls()
                .overlayArrangementEdge(.trailing)
        } secondary: {
            ReaderText()
        }
        .arrangementViewStyle(.overlay)
    }
}
```

## Rules

- Navigation goes around it. Put `NavigationStack` and `TabView` outside the arrangement. It lays out views; it doesn't navigate ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Arrangement-views), [111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=969)).
- Never nest it with a `NavigationSplitView`, in either order. The talk says not to put a split view inside an arrangement. The overview says not to put an arrangement inside a split view, and that includes its detail column ([overview](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)). The HIG's wording allows a split view around an arrangement; Duology follows the overview and the talk, as `duo-patterns` does. For list-detail, use `NavigationSplitView` on its own.
- Don't place it inside a `List`, a `ScrollView`, or anything else that could make part of it unreachable ([overview](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)).
- Scrolling goes inside a half: a `List` or `ScrollView` as the primary or secondary is fine.
- The primary must work alone. Split may show only the primary, and closed sideways it does.
- Don't drive it from the hinge. It already reads the fold.

## Deploying below iOS 27.1

`ArrangementView` and everything on this page need iOS 27.1. The snippets above are marked `@available(iOS 27.1, *)`, so they compile at any deployment target; call them inside `if #available(iOS 27.1, *)`. Gate it and fall back to an ordinary stack:

```swift
import SwiftUI

struct PlayerAndQueue: View {
    var body: some View {
        if #available(iOS 27.1, *) {
            ArrangementView {
                PlayerView()
            } secondary: {
                UpNextView()
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    PlayerView()
                    UpNextView()
                }
                PlayerView()
            }
        }
    }
}
```

## UIKit

`UIArrangementViewController` with `setViewController(_:for:animated:)`, `updateArrangement(_:animated:)` (`.split`, `.overlay`, `UISplitArrangement`, `UIOverlayArrangement`) and `state(for:)` for `zIndex`, `splitAxis` and `isHidden`. Code: [uikit.md](uikit.md#arrangements).
