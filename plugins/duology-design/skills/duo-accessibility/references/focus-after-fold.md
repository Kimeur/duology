# Focus after fold and unfold

When iPhone Duo folds or unfolds, the window moves to the other display and resizes. Views appear and disappear. A VoiceOver user who was on a list row can find themselves at the top of the screen with no idea what changed. This file shows what VoiceOver does on its own, and how to put it back on the person's place.

## What VoiceOver does on its own

*Measured* on the iPhone Duo simulator (details in [evidence.md](evidence.md#focus-after-a-fold)). The screen showed a list and a message side by side when open, and only the message when closed. VoiceOver was on "Row 2" of the list, then the phone was closed in Device Hub:

| What the app did | Where VoiceOver was 4 s later |
|---|---|
| Nothing | `Back, Button`: the first element on screen |
| Set `AccessibilityFocusState` at once in `onChange(of: horizontalSizeClass)` | `Back, Button`: the request was lost |
| Set it 0.3 s after the size class changed | `Lunch on Friday, Heading`: the message title |

The same app with the size class forced through the environment, with no real resize, behaved differently: there, setting the focus at once worked, and posting `AccessibilityNotification.LayoutChanged()` without an element left VoiceOver on the Back button. Our reading: the real resize drops an early request. Test focus code with a real pose change, not a simulated size class.

Not measured: unfold (closed to open), partial fold, Split View, and real hardware. Device Hub had no open window in our second run, so we could not press the poses (*unverified*).

## The recipe

1. Remember the last element the person reached. `AccessibilityFocusState` updates when VoiceOver focus lands on a view bound with `accessibilityFocused(_:equals:)` ([doc](https://developer.apple.com/documentation/swiftui/accessibilityfocusstate)).
2. When the width class changes, wait for the new layout.
3. Move focus once: to the same element if it still exists, or to the closest one that does.

```swift
import SwiftUI

/// Moves VoiceOver to `target` after the width class changes (fold, unfold, Split View).
/// Measured: a move made at once was ignored during a real fold.
struct RefocusAfterResize<Value: Hashable>: ViewModifier {
    let focus: AccessibilityFocusState<Value?>.Binding
    let target: () -> Value?
    var delay: Duration = .milliseconds(500)
    @Environment(\.horizontalSizeClass) private var widthClass

    func body(content: Content) -> some View {
        content.task(id: widthClass) {
            guard (try? await Task.sleep(for: delay)) != nil, let value = target() else { return }
            focus.wrappedValue = value
        }
    }
}

struct Note: Identifiable, Hashable { let id: Int; var title: String }

/// List and note side by side when open, the note alone when closed.
struct NotesScreen: View {
    enum Spot: Hashable { case row(Note.ID), noteTitle }

    let notes: [Note]
    @State private var selection: Note.ID?
    @State private var lastSpot: Spot?
    @AccessibilityFocusState private var spot: Spot?
    @Environment(\.horizontalSizeClass) private var widthClass

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if widthClass == .regular || selection == nil {
                List(notes, selection: $selection) { note in
                    Text(note.title).accessibilityFocused($spot, equals: .row(note.id))
                }
                .accessibilityPane("Notes")
            }
            if let note = notes.first(where: { $0.id == selection }) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(note.title).font(.title)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($spot, equals: .noteTitle)
                    Text("Note body")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityPane("Note")
            }
        }
        .onChange(of: spot) { _, new in if let new { lastSpot = new } }
        .modifier(RefocusAfterResize(focus: $spot) { placeAfterResize() })
    }

    /// The person's place in the new layout.
    private func placeAfterResize() -> Spot? {
        switch lastSpot {
        case .row where widthClass != .regular && selection != nil:
            return .noteTitle  // the list is gone; the open note is the person's place
        case .noteTitle where selection == nil:
            return nil
        default:
            return lastSpot
        }
    }
}

extension View {
    func accessibilityPane(_ label: LocalizedStringKey) -> some View {
        accessibilityElement(children: .contain).accessibilityLabel(label)
    }
}
```

Why it is built this way:

- **`.task(id:)`, not `onChange` plus a `Task`.** The task restarts on every change and SwiftUI cancels the old one, so a fast fold and unfold moves focus once, for the final layout.
- **One move, no announcement.** Apple's focus guidance says not to move focus on your own, with one exception: when people step through items one at a time and the focused item disappears, move focus to a nearby item they can find ([HIG, Focus](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection#Best-practices)). VoiceOver moves one step at a time, and a fold is when items disappear. Don't also post an announcement; VoiceOver already speaks the element it lands on.
- **Remember, don't guess.** The fallback depends on what the person was doing. In list-detail, the open item is their place when the list goes away.
- **The delay.** Our run used `onChange` with a 0.3 s `Task.sleep`. The modifier above does the same through `.task(id:)`, with 0.5 s for slower moments. The modifier itself was not run on a real fold, nor on hardware (*unverified*).
- **Without VoiceOver.** Setting the focus state should do nothing visible when no assistive technology runs (*unverified*: we tested with VoiceOver on).

## Text fields and the keyboard focus

`@FocusState` (keyboard focus) is separate from `AccessibilityFocusState` (VoiceOver focus). To keep typing focus through a fold, keep the `TextField` in the same view identity on both layouts, as `duo-continuity` explains, and store which field was focused in `@SceneStorage` if the field can leave the screen. Whether the keyboard focus survives a real fold was not measured here (*unverified*).

## UIKit

Post `.layoutChanged` with the element to focus, after the transition ends ([doc](https://developer.apple.com/documentation/uikit/uiaccessibility/post(notification:argument:))):

```swift
import UIKit

final class NoteViewController: UIViewController {
    let titleLabel = UILabel()
    private var refocus: DispatchWorkItem?

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.moveVoiceOverAfterLayout()
        }
    }

    private func moveVoiceOverAfterLayout() {
        refocus?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, UIAccessibility.isVoiceOverRunning else { return }
            UIAccessibility.post(notification: .layoutChanged, argument: self.titleLabel)
        }
        refocus = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
}
```

The UIKit path was not measured on the simulator (*unverified*). The same rules apply: wait for the layout, move once, pick the person's place.

## Test it

The fold must be real. A UI test can't change the pose, so it waits while the pose changes:

1. The test launches the app, turns VoiceOver on and moves to a row, then logs `READY`.
2. Someone presses Closed in Device Hub, or you run `duo-pose set closed --force` from `duo-pose-matrix` once you have checked that no other test runs and the user agrees. `duo-pose` refuses without `--force` while a UI test runs, this one included ([testing.md](testing.md#focus-after-a-real-fold)).
3. The test waits for a marker that says the layout changed, waits 4 s more, then reads `currentSpeech()` and moves forward and back to confirm where VoiceOver is.

The full test is in [testing.md](testing.md#focus-after-a-real-fold).
