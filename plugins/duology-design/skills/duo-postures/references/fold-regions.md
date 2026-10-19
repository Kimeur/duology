# Fold regions: the two helpers

Every recipe in this skill reads the fold with `FoldGeometry` and places views with `FoldRegionsLayout`. Add both to the app once.

## FoldGeometry

This is the helper from `duo-patterns` ([SKILL.md](https://github.com/Kimeur/duology/blob/main/plugins/duology-design/skills/duo-patterns/SKILL.md#shared-helper-foldgeometry)) plus one filter, `liesInside(_:of:)`, which the gallery app's copy also has ([FoldGeometry.swift](https://github.com/Kimeur/duology/blob/main/samples/DuologyGallery/DuologyGallery/Shared/FoldGeometry.swift)). If the app already has a `FoldGeometry`, don't add a second copy: check that its `init(_:)` filters with `liesInside`, and add the filter if it doesn't. Keep `nonisolated`: a new Xcode 27.1 app makes types main-actor isolated by default, and `onGeometryChange` then rejects the `Equatable` conformance.

Why the filter: a reserved region query can return regions that lie wholly outside the view. *Measured* with `.occlusion` on the closed phone: a view 382 pt wide got the camera and status bar regions at x = 382 and x = 400 ([measurements](measurements.md#closed-outer-display-portrait)). We have not seen it for `.division`, but nothing rules it out. Without the filter, a pane or a Split View window beside the fold would read as book or tabletop.

```swift
import SwiftUI

/// Where the fold crosses a view, read from the view's reserved regions.
/// Layout input only. Never drive layout from the hinge angle.
@available(iOS 27.1, *)
nonisolated struct FoldGeometry: Equatable, Sendable {
    /// The fold's frame in this view's space, margins included. Nil when no fold
    /// splits the view in two, including a fold that lies outside it or only touches an edge.
    var frame: CGRect?
    /// True while the phone is partly folded. False when it lies flat.
    var isActive = false

    /// True when the fold runs top to bottom, so the view has a left half and a right half.
    var isVertical: Bool {
        guard let frame else { return false }
        return frame.height > frame.width
    }

    init(frame: CGRect? = nil, isActive: Bool = false) {
        self.frame = frame
        self.isActive = isActive
    }

    init(_ proxy: GeometryProxy) {
        // The default query returns active regions only. Ask for inactive ones too,
        // so a flat inner display still tells you where its fold is.
        // Keep only a fold with part of this view on each side of it.
        let size = proxy.size
        let folds = proxy.reservedRegions(kind: .division, options: .includeInactive)
            .filter { Self.liesInside($0.frame, of: size) }
        if let fold = folds.first(where: \.isActive) ?? folds.first {
            frame = fold.frame
            isActive = fold.isActive
        }
    }

    /// True when a fold frame splits a view of `size` into two non-empty parts:
    /// view left and right of a top to bottom fold, or above and below a side to side one.
    static func liesInside(_ frame: CGRect, of size: CGSize) -> Bool {
        if frame.height > frame.width {
            return frame.minX > 0 && frame.maxX < size.width
        }
        return frame.minY > 0 && frame.maxY < size.height
    }
}

@available(iOS 27.1, *)
extension View {
    /// Calls `action` with the fold geometry now and every time it changes.
    func onFoldChange(_ action: @escaping (FoldGeometry) -> Void) -> some View {
        onGeometryChange(for: FoldGeometry.self) { proxy in
            FoldGeometry(proxy)
        } action: { fold in
            action(fold)
        }
    }
}
```

What each pose gives you (from the [measurements](measurements.md)):

| Pose | `frame` | `isActive` | `isVertical` |
|---|---|---|---|
| Closed, tent, flipped (outer display) | `nil` | `false` | `false` |
| Open, flat, held wide | 40 pt wide, full height | `false` | `true` |
| Open, flat, held tall | full width, 40 pt high | `false` | `false` |
| Book | 40 pt wide, full height | `true` | `true` |
| Tabletop | full width, 40 pt high | `true` | `false` |

## FoldRegionsLayout

A custom [`Layout`](https://developer.apple.com/documentation/swiftui/layout) for two views: content first, controls second. It is one layout type in every pose, so SwiftUI never rebuilds either view: playback, scroll position and focus survive a fold.

```swift
import SwiftUI

// requires: FoldGeometry

/// Places two views in the regions a fold makes: content first, controls second.
/// Fold top to bottom (book): content leading, controls trailing.
/// Fold side to side (tabletop): content on top, controls below.
/// One layout in every pose, so both views keep their identity and state.
@available(iOS 27.1, *)
struct FoldRegionsLayout: Layout {
    enum Unfolded: Sendable {
        /// No active fold: controls float over the content at the bottom, like a ZStack.
        case overlay
        /// Split even when flat: at the fold line on the inner display, so folding
        /// moves nothing; in the middle, side by side or stacked, on the outer display.
        case split
    }

    var fold: FoldGeometry
    var unfolded: Unfolded = .overlay
    var spacing: CGFloat = 16

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let content = subviews[0]
        let controls = subviews[1]
        if let (first, second) = regions(in: bounds) {
            content.place(at: first.origin, proposal: ProposedViewSize(first.size))
            controls.place(at: CGPoint(x: second.midX, y: second.midY), anchor: .center,
                           proposal: ProposedViewSize(second.size))
        } else {
            content.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
            let height = controls.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
            controls.place(at: CGPoint(x: bounds.midX, y: bounds.maxY), anchor: .bottom,
                           proposal: ProposedViewSize(width: bounds.width, height: height))
        }
    }

    /// The content region and the controls region, or nil to overlay.
    private func regions(in bounds: CGRect) -> (CGRect, CGRect)? {
        // Region frames are in this view's own space; bounds can start anywhere.
        if let f = fold.frame, fold.isActive || unfolded == .split {
            let vertical = fold.isVertical
            let line = vertical ? f.midX : f.midY
            let length = vertical ? bounds.width : bounds.height
            // Use the fold only when it crosses the middle half of this view.
            // A fold at the very edge (a pane beside it) would leave one region empty.
            if line > length / 4, line < length * 3 / 4 {
                if vertical {
                    return (CGRect(x: bounds.minX, y: bounds.minY, width: f.minX, height: bounds.height),
                            CGRect(x: bounds.minX + f.maxX, y: bounds.minY,
                                   width: bounds.width - f.maxX, height: bounds.height))
                }
                return (CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: f.minY),
                        CGRect(x: bounds.minX, y: bounds.minY + f.maxY,
                               width: bounds.width, height: bounds.height - f.maxY))
            }
        }
        guard unfolded == .split else { return nil }
        // No fold in this view (the outer display): split in the middle.
        if bounds.width >= bounds.height {
            let width = (bounds.width - spacing) / 2
            return (CGRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height),
                    CGRect(x: bounds.maxX - width, y: bounds.minY, width: width, height: bounds.height))
        }
        let height = (bounds.height - spacing) / 2
        return (CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: height),
                CGRect(x: bounds.minX, y: bounds.maxY - height, width: bounds.width, height: height))
    }
}
```

### How it decides

| Fold in the view | `.overlay` | `.split` |
|---|---|---|
| None (outer display) | Content fills; controls at the bottom, over it | Two halves: side by side when wide, stacked when tall |
| Inactive (open, flat) | Content fills; controls at the bottom, over it | Two regions on each side of the fold line |
| Active, top to bottom (book) | Content leading, controls trailing | Content leading, controls trailing |
| Active, side to side (tabletop) | Content on top, controls below | Content on top, controls below |

- Pick `.overlay` when the content is one picture that should fill the screen while it can: video, a camera view, a map, a game.
- Pick `.split` when the two parts are equals that both need room: a timer and its controls, a photo and its details, a question and its answer pad.
- The content gets its whole region. The controls get their region as a proposal and sit centred in it, so a fixed-size control group stays compact and a flexible one fills the region.

### Rules

1. Read the fold on the view that uses the layout. `.onFoldChange` goes on the `FoldRegionsLayout` itself, so the region frames share its coordinate space. Read it anywhere else and the frames don't line up.
2. Pass the whole `FoldGeometry`, not a Boolean. The frame is what keeps the regions on the fold.
3. Keep the layout inside the safe area. Let a background or video extend with `.ignoresSafeArea()` on that subview only. Controls then stay clear of the home indicator and the side bars.
4. Right-to-left needs no extra code. SwiftUI mirrors region frames by default, and a `Layout` mirrors what it places, so content stays on the leading side ([`ReservedRegion`](https://developer.apple.com/documentation/swiftui/reservedregion)). Not yet tested on the simulator in a right-to-left language. (unverified)
5. Animate the move with `.animation(_:value: fold)`, and pass `nil` when Reduce Motion is on.

### Deploying below iOS 27.1

Both helpers need iOS 27.1. iPhone Duo ships with it, so the fallback only runs on other iPhones, where there is no fold anyway:

```swift
import SwiftUI
import AVFoundation

// requires: TabletopPlayer (SKILL.md)
// requires: PlayerSurface, PlayerControls (references/tabletop-media.md)

struct PlayerScreen: View {
    let player: AVPlayer

    var body: some View {
        if #available(iOS 27.1, *) {
            TabletopPlayer(player: player)
        } else {
            ZStack(alignment: .bottom) {
                PlayerSurface(player: player).ignoresSafeArea()
                PlayerControls(player: player)
            }
            .background(.black)
        }
    }
}
```

## Pitfalls

- **Splitting at `width / 2`.** Side bars make the view off-centre on the open phone, so its middle is not the fold. Use the fold frame.
- **Reading only active regions with `.split`.** The split would jump from the middle to the fold the moment someone folds. `FoldGeometry` asks for inactive regions too.
- **Swapping view trees.** `if fold.isActive { VStack { … } } else { ZStack { … } }` builds new views on every fold: a new video layer flashes black, scroll positions and focus reset. Keep one `Layout`.
- **Reading regions in `onAppear`.** The first layout pass has no regions. `onFoldChange` hears the next one.
- **A layout for each pose.** If you find yourself writing `case book`, `case tabletop`, stop. Two inputs (is there an active fold, which way does it run) cover every pose.
