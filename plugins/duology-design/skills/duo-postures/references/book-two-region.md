# Book pose: two regions

"Book" is Duology's word for what Apple describes as the phone partially folded like a book: held wide, the fold running top to bottom through the inner display. The display curves through the centre, so Apple moves text, images and buttons away from it and lets the curve split the layout in two ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=123)).

Use this recipe for a screen with one thing to read and one set of controls: a timer, a recipe step and its buttons, a photo and its edit tools, a question and its answer pad. For two equal panes of content (list and detail, a document and its preview), use a system split view or an arrangement instead (`duo-patterns`). For pages, use the two-page pattern in `duo-patterns`.

## How it behaves

| Pose | What you read | What you touch |
|---|---|---|
| Closed, portrait | Top half | Bottom half |
| Closed, landscape (tent) | Leading half | Trailing half |
| Open, flat, held wide | Leading side of the fold line | Trailing side |
| Book | Leading region | Trailing region |
| Open, flat, held tall | Above the fold line | Below it |
| Tabletop | Top region | Bottom region |

Folding only changes the fold from inactive to active, so on the inner display nothing moves when someone folds or unfolds. That is the point of `.split`: Apple asks for small adjustments, not rearrangement, as people fold ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions)).

Why controls go trailing: when the phone closes, the app continues on the outer display, where bars and alerts sit on the right. Apple moves alerts to the trailing side in book pose for the same reason ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=249)).

## Recipe: countdown timer

Needs `FoldGeometry` and `FoldRegionsLayout` from [fold-regions.md](fold-regions.md). Typechecks against the iOS 27.1 simulator SDK in Swift 5 and Swift 6 mode, with iOS 27.1 and iOS 26 deployment targets, and with main actor default isolation.

```swift
import SwiftUI

// requires: FoldGeometry, FoldRegionsLayout (fold-regions.md)
// requires: CountdownFace, CountdownControls (next block)

/// Two regions that use the fold as their divider.
/// Folded like a book: what you read on the leading side, what you touch on the trailing side.
/// Flat: the same split at the fold line, so folding moves nothing.
/// Closed: the same two views, stacked (portrait) or side by side (landscape).
@available(iOS 27.1, *)
struct CountdownScreen: View {
    @State private var fold = FoldGeometry()
    @State private var remaining = 300
    @State private var isRunning = false

    var body: some View {
        FoldRegionsLayout(fold: fold, unfolded: .split) {
            CountdownFace(remaining: remaining)
            CountdownControls(remaining: $remaining, isRunning: $isRunning)
        }
        .onFoldChange { fold = $0 }
        .task(id: isRunning) {
            guard isRunning else { return }
            while remaining > 0 {
                // Cancelled (paused, or the view went away): stop, keep the time.
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                remaining -= 1
            }
            isRunning = false
        }
    }
}
```

The two views it places:

```swift
import SwiftUI

struct CountdownFace: View {
    let remaining: Int

    var body: some View {
        Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
            .font(.system(size: 96, weight: .semibold, design: .rounded).monospacedDigit())
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Time left")
            .accessibilityValue(Text(Duration.seconds(remaining), format: .units(allowed: [.minutes, .seconds])))
    }
}

struct CountdownControls: View {
    @Binding var remaining: Int
    @Binding var isRunning: Bool

    var body: some View {
        VStack(spacing: 16) {
            Button(isRunning ? "Pause" : "Start", systemImage: isRunning ? "pause.fill" : "play.fill") {
                isRunning.toggle()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
            HStack(spacing: 12) {
                Button("Add 1 Minute", systemImage: "plus") { remaining += 60 }
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    isRunning = false
                    remaining = 300
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

What the recipe does on purpose:

- Both views fill their region (`maxWidth` and `maxHeight` of `.infinity`), so each centres its content inside its own side of the fold.
- The time scales down (`minimumScaleFactor`) instead of wrapping. On the closed phone, in portrait, each stacked half is about 382 × 314 pt (*derived*: the 382 × 644 pt safe area that `duo-layout` measured, minus the 16 pt spacing, halved).
- The controls are the same three buttons in every pose. Nothing hides when the phone closes.
- `.task(id:)` restarts the tick when `isRunning` changes. The layout never owns the timer state, so a fold can't reset it.
- The tick stops when its task is cancelled. SwiftUI cancels `.task` when `isRunning` changes and when the view leaves the screen (another screen pushed, another tab). Never write `try? await Task.sleep` in this loop: it swallows the cancellation, and the loop then counts down to 0 in a burst. The time stays put while the view is away and the tick resumes when it comes back.
- A shipping timer stores its end time as a `Date` and derives `remaining` from it, so it stays right while the screen is away or the app is in the background. The recipe keeps a plain counter to stay short.

## Other screens with the same shape

Swap the two views and keep the layout:

| Screen | First view (read) | Second view (touch) |
|---|---|---|
| Recipe steps | The current step, large | Previous, Next, a timer |
| Photo editing | The photo | Tool palette and sliders |
| Flash cards | The question | Answer buttons |
| Calculator | The display and history | The keypad |

If the second view scrolls (a long list of tools), give it its own `ScrollView`. Scrolling content may sit next to the fold; it just must not be moved around it ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=225)).

## Per-region controls

A screen often has toolbar items for the whole screen and controls for one region. Keep each where it belongs:

- Screen-wide actions (Share, Done) go in the system toolbar. It moves to the side and off the fold on its own.
- Controls that act on one region stay in that region, at its top or bottom edge. Mail keeps list controls above the list pane instead of moving them to the side bar ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls)).
- Search stays over the view it searches; when the phone folds, it narrows to that region ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=290)).

## Rules

1. Split at the fold, never at `width / 2`. Bars make the view off-centre on the open phone.
2. Use `.split` so the flat and folded layouts are the same. Use `.overlay` only when the content should fill the screen until someone folds (video, camera, maps).
3. Nothing interactive in the fold frame, margins included.
4. Fit images and text to one region. A photo across the curve stops reading as one picture.
5. Same controls in every pose.

## Pitfalls

- **Centring across the fold.** A single centred column of text or a centred card sits right in the curve. Put it in one region or make it two columns. Apple's first step for existing apps is to audit centred layouts this way ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=999)).
- **Two layouts, one for flat and one for book.** The view tree is rebuilt on every fold and the screen jumps. Keep one layout.
- **Moving scrolling content.** A feed or article that shrinks into one region when folded is the mistake Apple names. Scrolling content stays where it is.
- **Controls on the leading side.** They end up far from where they sit once the phone closes.

## Test it

1. Open, held wide: the face is left of the fold line, the buttons right of it.
2. Partially Open: nothing moves; no button touches the fold's 40 pt frame.
3. Start the timer, close the phone: it keeps counting, and the stacked layout shows the same buttons.
4. Partially Open, then Rotate Right once (tabletop): face on top, buttons below.
5. Closed and rotated (tent): face and buttons side by side.
6. Right-to-left language: the face sits on the right (leading) side. (unverified)

The region frames this relies on were measured folded with the gallery app; this screen has not yet run folded on the simulator. (unverified)

## Sources

IDs point to [`reference/sources.md`](https://github.com/Kimeur/duology/blob/main/reference/sources.md): D2 (HIG), V3 (talk 111463), V6 (talk 111466).
