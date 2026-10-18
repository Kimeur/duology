# Keyboard, Full Keyboard Access, Switch Control and Voice Control

Ways people use iPhone Duo without touching the screen, or without precise touch. All of them rely on the same thing: real controls with clear names, reachable in a sensible order.

## Hardware keyboard

Any iPhone works with an external keyboard, and Apple asks you to test with one ([Testing system accessibility features](https://developer.apple.com/documentation/accessibility/testing-system-accessibility-features-in-your-app)). The open inner display makes typing setups more likely, but nothing in Apple's iPhone Duo pages or talks treats the keyboard differently on Duo.

### Shortcuts

```swift
import SwiftUI

struct NotesToolbar: View {
    let newNote: () -> Void
    let search: () -> Void
    let toggleSidebar: () -> Void

    var body: some View {
        HStack {
            Button("New Note", systemImage: "square.and.pencil", action: newNote)
                .keyboardShortcut("n")                          // Command is the default modifier
            Button("Search", systemImage: "magnifyingglass", action: search)
                .keyboardShortcut("f")
            Button("Show Sidebar", systemImage: "sidebar.leading", action: toggleSidebar)
                .keyboardShortcut("s", modifiers: [.command, .control])
        }
    }
}
```

- `keyboardShortcut(_:modifiers:)` defaults to Command ([doc](https://developer.apple.com/documentation/swiftui/view/keyboardshortcut(_:modifiers:))). Prefer Command, keep standard shortcuts for their standard actions, and add custom ones only for frequent commands ([HIG, Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards#Best-practices)).
- A shortcut works while its control is somewhere in the active scene ([doc](https://developer.apple.com/documentation/swiftui/view/keyboardshortcut(_:modifiers:))). Closed, a pane that isn't on screen takes its shortcuts with it, so put screen-wide shortcuts on views that exist in both layouts.
- When two controls share a shortcut, the first one found leading to trailing wins (same doc). Open, with two panes, give each shortcut one owner.
- *Measured* in UI tests on the closed display: `typeKey("n", modifierFlags: .command)` ran the action. In one run it was ignored until the app had been tapped once, and after a tap, two presses counted once. Assert after each press and wait for the result.

### Focus

- `@FocusState` with `focused(_:equals:)` moves keyboard focus between text fields; `defaultFocus(_:_:priority:)` picks the first one ([doc](https://developer.apple.com/documentation/swiftui/view/defaultfocus(_:_:priority:))).
- `focusSection()` is unavailable on iOS (macOS and tvOS only, iOS 27.1 SDK). Don't use it.
- `onKeyPress(_:action:)` reacts only while its view has focus ([doc](https://developer.apple.com/documentation/swiftui/view/onkeypress(_:action:))).
- *Measured* closed, in UI tests: `UIFocusSystem.focusSystem(for:)` returned nil in every run, Tab never reached views marked `focusable()`, and `onKeyPress(.space)` never fired. Tab moved from one text field to the next in one run and did nothing in another. The inner display was not measured (*unverified*).
- iPad's focus system (Tab between groups, arrows inside a group) is an iPadOS feature in Apple's guidance ([HIG, Focus](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection#iPadOS)). Don't assume the inner display behaves like an iPad. Make everything work with Full Keyboard Access instead.

```swift
import SwiftUI

struct ReplyForm: View {
    enum Field: Hashable { case to, subject, body }
    @FocusState private var field: Field?
    @State private var to = ""
    @State private var subject = ""
    @State private var text = ""

    var body: some View {
        Form {
            TextField("To", text: $to).focused($field, equals: .to)
                .onSubmit { field = .subject }
            TextField("Subject", text: $subject).focused($field, equals: .subject)
                .onSubmit { field = .body }
            TextField("Message", text: $text, axis: .vertical).focused($field, equals: .body)
        }
        .defaultFocus($field, .to)
    }
}
```

`onSubmit` moves focus with Return, which works whether or not Tab does.

## Full Keyboard Access

Full Keyboard Access lets people reach and activate every control from the keyboard ([HIG, Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards#Best-practices)). Turn it on in Accessibility Inspector's Settings pane, or in Settings > Accessibility > Keyboards in the simulator.

- System controls work. Custom views that take taps must be accessibility elements with the button trait and an action.
- It uses input labels too ([doc](https://developer.apple.com/documentation/swiftui/view/accessibilityinputlabels(_:))).
- Check closed and open: every control in both panes is reachable.

## Voice Control

People say the name of what they see: "Tap Reply". Apple asks for clear labels so this works ([HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Mobility)). Voice Control uses your input labels, and the accessibility label when you give none ([doc](https://developer.apple.com/documentation/swiftui/view/accessibilityinputlabels(_:))).

- Vertical bars show symbols. Give every bar item a title and a symbol, as Apple asks; the title stays in the overflow menu and in the accessibility label ([HIG, iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls)).
- Make the label match visible text when there is any. People can't guess a hidden name.
- Add short alternatives with `accessibilityInputLabels`, most important first.

```swift
import SwiftUI

struct PlayerButton: View {
    let isPlaying: Bool
    let toggle: () -> Void

    var body: some View {
        Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill", action: toggle)
            .labelStyle(.iconOnly)
            .accessibilityInputLabels(isPlaying ? ["Pause", "Stop"] : ["Play", "Start"])
    }
}
```

## Switch Control

Switch Control moves a highlight through items and lets people act on the highlighted one with one or more switches ([doc](https://developer.apple.com/documentation/accessibility/switch-control)).

- Every drag, swipe, pinch and hinge input needs a button or a named action. `accessibilityAction(named:_:)` adds one to the actions menu ([doc](https://developer.apple.com/documentation/swiftui/view/accessibilityaction(named:_:))).
- Group each pane (see [voiceover-order.md](voiceover-order.md)). Switch Control scanning likely benefits from the same groups, so people can skip a whole pane (*unverified*: we did not run Switch Control).
- No timed controls that vanish before a scan reaches them ([HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Cognitive)).
- `accessibilitySwitchControlEnabled` exists, but design for everyone instead of branching on it ([doc](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityswitchcontrolenabled)).

```swift
import SwiftUI

struct ReorderableCard: View {
    let title: String
    let moveUp: () -> Void
    let moveDown: () -> Void

    var body: some View {
        Text(title)
            .padding()
            .background(.quaternary, in: .rect(cornerRadius: 12))
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: "Move Up", moveUp)       // the drag has a tap path
            .accessibilityAction(named: "Move Down", moveDown)
    }
}
```

## UIKit

```swift
import UIKit

final class NotesViewController: UIViewController {
    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(title: "New Note", action: #selector(newNote), input: "n", modifierFlags: .command)]
    }

    @objc private func newNote() {}

    func configure(replyButton: UIButton, card: UIView) {
        replyButton.accessibilityUserInputLabels = ["Reply", "Answer"]
        card.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "Move Up") { _ in true },
            UIAccessibilityCustomAction(name: "Move Down") { _ in true },
        ]
    }
}
```

The view controller must be in the responder chain for its key commands to fire.
