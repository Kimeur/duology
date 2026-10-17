# Displacement

When the phone is partly folded, controls that would sit in the curve move to the nearest region that suits them. Scrolling content stays where it is. This is Apple's own pattern for iPhone Duo, named and explained in [talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=146).

Prior art: Samsung's [Flex mode](https://developer.samsung.com/galaxy-z/flex-mode.html) (content on top, controls below when the phone rests half folded) and Android's [fold-aware layouts](https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/make-your-app-fold-aware).

## Use it when

- You place a control yourself, near the middle of the screen: a floating action button, a record button, a playback bar, a custom popover, a centred empty-state button.
- System components don't cover it. Sheets, alerts, action sheets, menus, popovers and toolbar buttons already move off the fold, and system split views even out their columns ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=312), [talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=568)).

Apple's advice for an existing app: find your highest-priority controls that you lay out by hand, and adopt reserved regions for those ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=994)).

## How it behaves

| State | Controls | Scrolling content |
|---|---|---|
| Closed | Where you designed them | Unchanged |
| Open, flat | Where you designed them. The fold is inactive. | Unchanged |
| Partly folded like a book (fold runs top to bottom) | Move to the trailing region, near where they will be once the phone closes | Unchanged, may cross the fold |
| Partly folded across, propped on a table | Interactive controls move to the bottom region; things to look at from a distance go to the top region | Unchanged |

The book and table cases come from [talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=240). Apple's [design talk](https://developer.apple.com/videos/play/tech-talks/111466/?time=222) adds: if you design a special layout for the phone set on a table, keep the same controls and hierarchy as in every other state.

## Apple APIs

| Need | SwiftUI | UIKit | Availability |
|---|---|---|---|
| Where the fold is and whether it is active | [`reservedRegions(kind: .division, options:)`](https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:)), wrapped in `FoldGeometry` (SKILL.md) | [`reservedRegions(kind:options:)`](https://developer.apple.com/documentation/uikit/uiview/reservedregions(kind:options:)) | iOS 27.1 |
| Where a camera covers the screen | the same call with `.occlusion` | the same call with `.occlusion` | iOS 27.1 |
| Re-read on change | [`onGeometryChange(for:of:action:)`](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)) | `layoutSubviews` (unverified as a trigger for fold changes) | iOS 16 |
| Mirrored frames for right-to-left | default `layoutDirectionBehavior: .mirrors`; pass `.fixed` for raw frames | not documented; test it | iOS 27.1 |

Region frames include margins for interactive content ([`ReservedRegion.frame`](https://developer.apple.com/documentation/swiftui/reservedregion/frame)). Keep buttons out of the whole frame.

There is no posture or "book mode" API. Don't use `onHingeChange` to move controls; Apple keeps the hinge for interactions and effects, and layout for reserved regions and arrangements ([talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/)).

## Rules

1. Pick the scope. Move a single control when it works alone. Move a group when its parts belong together (a timer and its button). Move a whole container when that is the unit ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=146)).
2. Move as little as you can. A control that jumps across the screen loses its link to the content it acts on. Keep its edge (bottom stays bottom) and go to the nearest region.
3. Let the purpose pick the region: trailing when folded like a book; bottom for touch and top for viewing when propped on a table.
4. Stay contextual. If a control belongs to one pane, keep it with that pane. Apple's example is search staying over the view it searches.
5. Never displace scrolling content. Lists, feeds, articles and documents already adapt by scrolling; moving them breaks continuity ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=146)).
6. Keep the same controls. Displacement moves, resizes and regroups; it never removes ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=312)).
7. Animate the move with the system's spring so people can follow it.
8. Check occlusions too. When the inner front camera is active, its region is active; keep controls out of it if the camera view is central to your screen ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=27)).

## What we measured

iOS 27.1 iPhone Duo simulator, open and flat, 951 × 669 pt window, no camera running:

- Division, default query: none. With `.includeInactive`: one inactive region, 40 pt wide with 20 pt margins on each side, centred, full height. So the default query is "active only", as the talk says. Apple's `ReservedRegion` page says the query returns regions whether or not they are active; on this simulator it did not.
- Occlusion, default query: one active 84 × 124 pt region in the top trailing corner, where the inner display's status bar sits. With `.includeInactive`: a second, inactive 58 × 37 pt region near the top, likely the inner front camera. (Which hardware each region stands for is our reading, not Apple's.)
- The first read in `onAppear` returned no regions. The next geometry update had them.

## Recipe

Needs `FoldGeometry` from SKILL.md. Typechecks against the iOS 27.1 simulator SDK, also with an iOS 26 deployment target.

```swift
import SwiftUI

// requires: FoldGeometry (SKILL.md)

@available(iOS 27.1, *)
struct VoiceMemoScreen: View {
    let memos: [String]
    @State private var fold = FoldGeometry()
    @State private var isRecording = false

    var body: some View {
        GeometryReader { proxy in
            let region = controlRegion(in: proxy.size)
            ZStack {
                // Scrolling content stays put. It may scroll across the fold.
                List(memos, id: \.self) { Text($0) }

                // One group moves as a unit, so the timer stays next to its button.
                RecordControls(isRecording: $isRecording)
                    .frame(width: region.width, height: region.height, alignment: .bottom)
                    .position(x: region.midX, y: region.midY)
            }
        }
        .onFoldChange { fold = $0 }
        .animation(.smooth, value: fold)
    }

    /// Where the controls may sit. Small move: same bottom edge, nearest region.
    private func controlRegion(in size: CGSize) -> CGRect {
        let whole = CGRect(origin: .zero, size: size)
        guard fold.isActive, let frame = fold.frame else { return whole }
        if fold.isVertical {
            // Folded like a book: the trailing region. SwiftUI mirrors region frames
            // for right-to-left layouts, so maxX is the trailing side in both.
            return CGRect(x: frame.maxX, y: 0, width: size.width - frame.maxX, height: size.height)
        }
        // Folded across, propped on a table: controls go to the bottom region.
        return CGRect(x: 0, y: frame.maxY, width: size.width, height: size.height - frame.maxY)
    }
}

struct RecordControls: View {
    @Binding var isRecording: Bool

    var body: some View {
        HStack(spacing: 16) {
            Text(isRecording ? "Recording" : "Ready")
                .font(.headline.monospacedDigit())
            Button(isRecording ? "Stop" : "Record",
                   systemImage: isRecording ? "stop.fill" : "record.circle") {
                isRecording.toggle()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial, in: Capsule())
        .padding(.bottom)
    }
}
```

What the recipe does on purpose:

- The list fills the screen and never moves.
- The status text and the button move together.
- Flat or closed, `controlRegion` is the whole view, so the group stays bottom centre.
- The controls keep their bottom edge in every state. Only the horizontal (book) or vertical (table) region changes.
- The `List` bottom rows can sit under the controls. Add a bottom content margin the height of the group if that hides content.

## Pitfalls

- **Displacing the list.** Shrinking a feed to one half when folded is the mistake Apple names. Move controls only.
- **Moving everything.** Small adjustments beat rearranging ([HIG, Reserved regions](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions)).
- **Hard-coded halves.** `size.width / 2` is not the fold. Bars and the status bar make the content area asymmetric.
- **Reading regions once.** The first read can be empty. Use `onGeometryChange`.
- **Custom popups in the middle.** Use system alerts, sheets and menus; they move for you.
- **Dropping controls when folded.** Same controls in every state.

## Test it

1. Closed and open flat: the group sits bottom centre.
2. Partially Open, held wide: the group slides to the trailing region, bottom edge unchanged. The list doesn't move.
3. Partially Open, held tall: the group sits in the bottom region.
4. Right-to-left language: the group moves to the left region (the trailing side). (unverified)
5. VoiceOver: the order is list, then controls, in every state.

Duology has not run steps 2 to 4: the folded poses can only be set by hand in Device Hub (`simctl` has no pose command in Xcode 27.1).

## Gallery screen

[`samples/DuologyGallery/DuologyGallery/Patterns/DisplacementView.swift`](../../../../../samples/DuologyGallery/DuologyGallery/Patterns/DisplacementView.swift)

## Sources

IDs point to [`reference/sources.md`](../../../../../reference/sources.md): D1 (hub), D2 (HIG), V3 (talk 111463), V4 (talk 111464), V6 (talk 111466), P2b (Android fold-aware), P3 (Samsung Flex mode).
