# SwiftUI transition patterns

Each block typechecks against the iOS 27.1 simulator SDK in Swift 5 mode, Swift 6 mode, and Swift 6 with `MainActor` as the default isolation. The transaction rules in the first section ran in a probe on the iPhone Duo simulator ([evidence.md](evidence.md)). The screen recipes are typechecked only: watch them in Device Hub before you rely on how they look.

## The transaction, in more detail

Apple's model, from [WWDC23 Explore SwiftUI animation](https://developer.apple.com/videos/play/wwdc2023/10156/) and the [`Transaction`](https://developer.apple.com/documentation/swiftui/transaction) page:

- Something happens (a tap, a timer, a resize) and SwiftUI opens an update. It runs `body` for the views whose inputs changed, then lays out.
- The update carries a transaction: a small set of values that travels down the view tree. Its `animation` decides how animatable values change in this update.
- An animatable value with no animation in its transaction takes its new value in the next frame. With an animation, SwiftUI interpolates from where it is now to the new value.
- `withAnimation` and `withTransaction` set the transaction for a state change you make in their closure. They do nothing for a change you did not make, such as a resize.
- [`animation(_:value:)`](https://developer.apple.com/documentation/swiftui/view/animation(_:value:)) sets the animation for the views under it, in the updates where `value` changed. `nil` means no animation for them.
- [`transaction(_:)`](https://developer.apple.com/documentation/swiftui/view/transaction(_:)) edits the transaction for the views under it in every update. Apple asks you to put it on leaf views; on a container it runs for the whole subtree. [`transaction(value:_:)`](https://developer.apple.com/documentation/swiftui/view/transaction(value:_:)) (iOS 17) does the same only when `value` changes.
- [`disablesAnimations`](https://developer.apple.com/documentation/swiftui/transaction/disablesanimations) stops `animation(_:)` modifiers below from adding an animation. Apple's example on the `transaction(value:_:)` page spells it `disableAnimations`, which does not compile; the SDK property is `disablesAnimations`.
- SwiftUI applies frame changes at the leaf views that draw. So an opt-out on a container stops its frame too, and [`geometryGroup()`](https://developer.apple.com/documentation/swiftui/view/geometrygroup()) makes a group resolve and animate its frame as one unit.

*Measured* on the iPhone Duo simulator, with `Animatable` probes that log every value SwiftUI hands them ([evidence.md](evidence.md)):

- Open, close and a quarter-turn rotation all reached SwiftUI with no animation. A probe with no opt-in took its new value in one step every time.
- During a rotation, `body` ran inside UIKit's 0.3 s rotation animation (`UIView.inheritedAnimationDuration` read 0.3). No SwiftUI value interpolated anyway: in our probe, UIKit's animation context did not become a SwiftUI animation.
- `.animation(.linear(duration: 0.5), value: horizontalSizeClass)` interpolated: 27 to 30 in-between values over 0.5 s. The first one came about 60 to 80 ms after a real open or close, and 25 to 40 ms after a size-class flip made from code. That is simulator timing; a device will differ.
- Under that opt-in, `.transaction { $0.animation = nil }` on a leaf and `.animation(nil, value:)` both gave one step.
- On open, the size class and the new size arrived in the same update. On close, the size class flipped 25 to 70 ms before the window shrank, in an update of its own. A spring started by the size class is still running when the size changes, and springs keep their velocity when the target moves ([WWDC23 Animate with springs](https://developer.apple.com/videos/play/wwdc2023/10158/?time=900)).

## See what a change hands you

Add this while debugging, then remove it. It is the probe behind the measured lines above. SwiftUI hands an `Animatable` modifier every in-between value of an animated change, and only the final value of one that isn't animated.

```swift
import SwiftUI

/// Debug only: prints every value SwiftUI hands it. Remove before shipping.
/// One line per change: no animation reached this view. A run of values between 0 and 1: it animated.
struct AnimationProbe: ViewModifier, Animatable {
    let label: String
    var progress: Double
    // nonisolated: Animatable isn't main-actor isolated, and Swift 6 mode checks that.
    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        print(label, progress)
        return content
    }
}
```

Usage: inside the subtree you want to check, add `.modifier(AnimationProbe(label: "layout", progress: isWide ? 1 : 0))`. Press Open and Closed in Device Hub and read Xcode's console.

- Don't rely on logging from `transaction(_:)` for this. In our probe its closure skipped some updates, including the one where the size class flipped on Open, so a missing line proved nothing.

## A pane that comes and goes, with a shared element

Closed, a mini player sits under the list. Open, a player pane sits beside it. The list keeps its place in the view tree in both sizes, so it keeps its scroll position and selection. The artwork is the one element that changes container, so it alone gets `matchedGeometryEffect`.

```swift
import SwiftUI

struct Track: Identifiable, Hashable {
    let id: Int
    var title: String
    var artist: String
}

struct LibraryWithPlayer: View {
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var player
    let tracks: [Track]
    let nowPlaying: Track

    var body: some View {
        let isWide = widthClass == .regular
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TrackList(tracks: tracks)              // same place in the tree in both sizes
                if isWide {
                    PlayerPane(track: nowPlaying, namespace: player)
                        .transition(.opacity)
                }
            }
            if !isWide {
                MiniPlayer(track: nowPlaying, namespace: player)
                    .transition(.opacity)
            }
        }
        // One animated update removes one artwork and inserts the other,
        // so matchedGeometryEffect moves a single picture from the bar to the pane.
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: isWide)
    }
}

struct ArtworkView: View {
    let track: Track
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.tint)
            .overlay { Image(systemName: "music.note").foregroundStyle(.white) }
            .aspectRatio(1, contentMode: .fit)
    }
}

struct MiniPlayer: View {
    let track: Track
    let namespace: Namespace.ID
    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(track: track)
                .matchedGeometryEffect(id: "artwork", in: namespace)
                .frame(width: 44, height: 44)
            Text(track.title).lineLimit(1)
            Spacer()
            PlayPauseButton()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct PlayerPane: View {
    let track: Track
    let namespace: Namespace.ID
    var body: some View {
        VStack(spacing: 16) {
            ArtworkView(track: track)
                .matchedGeometryEffect(id: "artwork", in: namespace)
                .frame(maxWidth: 280)
            Text(track.title).font(.title2.bold())
            Text(track.artist).foregroundStyle(.secondary)
            PlayPauseButton()                          // same control, same symbol, same tint
        }
        .padding()
        .frame(maxWidth: 360, maxHeight: .infinity)
    }
}

struct PlayPauseButton: View {
    var body: some View {
        Button("Play", systemImage: "play.fill") {}
            .labelStyle(.iconOnly)
            .buttonStyle(.borderedProminent)
    }
}

struct TrackList: View {
    let tracks: [Track]
    var body: some View {
        List(tracks) { Text($0.title) }
    }
}
```

Rules for [`matchedGeometryEffect`](https://developer.apple.com/documentation/swiftui/view/matchedgeometryeffect(id:in:properties:anchor:issource:)), from Apple's page:

- It links frames, nothing else. Each side still draws with its own transition, and neither side keeps the other's state. Use it on pictures, shapes and labels, never on a view that holds `@State`, focus or a player.
- The move happens only when one view is removed and the other inserted in the same animated update. That is why the `.animation(_:value:)` sits on their common parent.
- Exactly one view per ID may be the source. Two inserted sources give undefined results.
- Prefer `AnyLayout` whenever the views stay in one container. Reach for this effect only when the element really changes container.

Playback state lives in a model above this view, as `duo-continuity` shows. The play button is the same control with the same look in both places.

## Grid columns that move with the resize

Read the column count from the size class in `body`. The count then changes in the same update as the size class, and the tiles move to their new cells because `ForEach` gives them stable IDs.

```swift
import SwiftUI

struct Photo: Identifiable, Hashable {
    let id: Int
}

struct PhotoGrid: View {
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let photos: [Photo]

    var body: some View {
        // From the size class, in body: the count changes in the update that brings the size class.
        let columns = widthClass == .regular ? 4 : 2
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                ForEach(photos) { photo in             // stable IDs: each tile moves to its new cell
                    PhotoTile(photo: photo)
                }
            }
            .scrollTargetLayout()
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: columns)
        }
    }
}

struct PhotoTile: View {
    let photo: Photo
    var body: some View {
        Rectangle().fill(.quaternary).aspectRatio(1, contentMode: .fit)
            .overlay { Text("\(photo.id)") }
    }
}
```

- Pair it with `scrollPosition` by item ID from `duo-continuity`, so the top item stays in view.
- If the glide fights the scroll anchor in your recording, drop the animation for the grid (`.animation(nil, value: columns)`). A grid that snaps into place is fine; a grid that loses the reader's place is not.
- `ForEach(photos.indices, id: \.self)` breaks this: tiles keep their index, not their photo, so pictures swap instead of moving.

### Columns that need the real width

The size class is coarse. When you need the real width or the fold, as `duo-patterns` does for feed reflow, read it with `onGeometryChange`. The width only exists after layout, so the count changes in a follow-up update.

```swift
import SwiftUI

struct ShelfGrid: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var columns = 2
    let photos: [Photo]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                ForEach(photos) { PhotoTile(photo: $0) }
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: columns)
        }
        // The width comes back after layout, so the count changes one update later.
        .onGeometryChange(for: Int.self) { proxy in
            max(2, Int(proxy.size.width / 180) / 2 * 2)   // even counts
        } action: { newCount in
            columns = newCount
        }
    }
}
```

- *Measured:* on Open, the geometry action and the size-class update ran in the same millisecond in our probe. Whether a frame with the old count reaches the screen first is *unverified*; check a recording.
- *Measured:* on Open, a full-width view's width went 382 → 466 → 951 → 867 pt within 50 to 250 ms, as the safe area insets changed around the resize. The transform runs for each.

- Return the column count from the transform, not the width. The action then runs only when the count changes, and the animation key stays discrete.
- `duo-patterns`' feed reflow doesn't animate. If you add an animation to it, key it on the column count it derives, not on `FeedGridInput`, which holds the width and would retarget the animation at every one of those passes.

## Opt out of motion

```swift
import SwiftUI

struct TrackRow: View {
    @Environment(\.horizontalSizeClass) private var widthClass
    let track: Track

    var body: some View {
        let isWide = widthClass == .regular
        HStack {
            ArtworkView(track: track).frame(width: 44, height: 44)
            // The text swaps without a cross-fade; the row still moves with the layout.
            Text(isWide ? "\(track.title) - \(track.artist)" : track.title)
                .contentTransition(.identity)
            Spacer()
            // A live value that must never lag behind: no animation reaches this leaf.
            Text("3:41")
                .monospacedDigit()
                .transaction { $0.animation = nil }
        }
    }
}
```

| Tool | Stops | Keeps |
|---|---|---|
| `.contentTransition(.identity)` | The cross-fade of a text or symbol whose content changed | The frame's movement |
| `.contentTransition(.interpolate)` | Nothing; it morphs the glyphs instead of fading, when the string stays the same | Everything |
| `.transaction { $0.animation = nil }` on a leaf | All animation of that leaf, frame included | Its siblings' animations |
| `.animation(nil, value: key)` on a subtree | All animation in that subtree when `key` changes | Animation from other changes |

Content transitions only matter inside an animated update ([`ContentTransition`](https://developer.apple.com/documentation/swiftui/contenttransition)). [`interpolate`](https://developer.apple.com/documentation/swiftui/contenttransition/interpolate) falls back to a fade between different fonts or designs.

## Reduce Motion as one value

Decide once per screen, then use the result for every animation and transition on it.

```swift
import SwiftUI

struct ResizeMotion {
    let reduceMotion: Bool
    let prefersCrossFade: Bool

    /// Layout changes: a spring, or nothing under Reduce Motion.
    var layout: Animation? { reduceMotion ? nil : .smooth(duration: 0.3) }
    /// Views that appear or disappear: a short fade under Reduce Motion, a fade and a slide otherwise.
    var insertion: AnyTransition {
        prefersCrossFade || reduceMotion
            ? .opacity.animation(.easeInOut(duration: 0.2))
            : .opacity.combined(with: .move(edge: .trailing))
    }
}

@available(iOS 26.4, *)
struct MotionAwarePanes<Main: View, Side: View>: View {
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityPrefersCrossFadeTransitions) private var prefersCrossFade
    @ViewBuilder var main: Main
    @ViewBuilder var side: Side

    var body: some View {
        let motion = ResizeMotion(reduceMotion: reduceMotion, prefersCrossFade: prefersCrossFade)
        let isWide = widthClass == .regular
        HStack(spacing: 0) {
            main
            if isWide {
                side.transition(motion.insertion)
            }
        }
        .animation(motion.layout, value: isWide)
    }
}
```

- [`accessibilityPrefersCrossFadeTransitions`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityprefersCrossFadeTransitions) is iOS 26.4 and later. Below that, pass `reduceMotion` for both values.
- The fade carries its own animation, so it runs even though the layout animation is `nil`. *Measured:* a transition with its own `.animation` ran its full 0.5 s on a size-class change that carried no animation; the same transition without one appeared in one step.
- Apple's list for Reduce Motion: tighter springs, fades instead of slides, no depth or blur animations, and motion that tracks a gesture is fine ([HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Cognitive)). A hinge effect that follows the angle directly is closer to tracking a gesture than to an automatic animation, but zoom and parallax still belong off.

## Keep a group moving as one

By default each leaf animates its own frame. When parts of a group must stay locked together during the move, add `geometryGroup()`.

```swift
import SwiftUI

struct MessageBubble: View {
    let text: String
    let isWide: Bool
    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            Image(systemName: "person.crop.circle")
            Text(text)
                .padding(10)
                .background(.fill, in: RoundedRectangle(cornerRadius: 14))
        }
        .frame(maxWidth: isWide ? 420 : 280, alignment: .leading)
        .geometryGroup()   // the avatar and the bubble animate as one frame, not two
    }
}
```

## Arrangements and displacement

- `ArrangementView` decides by itself when to split, stack, overlay or hide its secondary view. Apple's pages don't say whether those changes animate. Watch a recording before you add `.animation(_:value:)` around one. (unverified)
- Controls that move off the fold: the `duo-patterns` displacement recipe keys `.animation(.smooth, value: fold)` on its `FoldGeometry` value. A partial fold doesn't resize the window, so nothing else animates that move for you.

## Sources

- [WWDC23 Explore SwiftUI animation](https://developer.apple.com/videos/play/wwdc2023/10156/): updates, transactions, animatable attributes, scoped animations.
- [WWDC21 Demystify SwiftUI](https://developer.apple.com/videos/play/wwdc2021/10022/): view identity, and why a branch creates new views.
- [WWDC23 Animate with springs](https://developer.apple.com/videos/play/wwdc2023/10158/): springs keep their velocity when the target changes mid-flight.
- Apple pages linked inline: `Transaction`, `animation(_:value:)`, `transaction(_:)`, `transaction(value:_:)`, `disablesAnimations`, `geometryGroup()`, `matchedGeometryEffect`, `ContentTransition`, `accessibilityPrefersCrossFadeTransitions`.
