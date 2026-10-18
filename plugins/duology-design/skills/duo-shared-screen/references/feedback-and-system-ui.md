# Haptics and system UI on a shared screen

Haptics per half, and what to switch off while two people play. The types come from [SKILL.md](../SKILL.md).

*Measured* means we ran it on the iPhone Duo simulator (Xcode 27.1, iOS 27.1). *Unverified* means we could not confirm it.

## Haptics per half

Attach one `sensoryFeedback` to each half and trigger it from that seat's own state. SwiftUI has three forms (iOS 17, [doc](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:condition:))):

| Form | Use it for |
|---|---|
| `sensoryFeedback(_:trigger:)` | one pattern on every change |
| `sensoryFeedback(_:trigger:condition:)` | one pattern on some changes, for example only when a count goes up |
| `sensoryFeedback(trigger:_:)` | a different pattern, or none, depending on the old and new values |

```swift
import SwiftUI

/// What happened to a seat, for its half's haptic.
nonisolated enum SeatEvent: Equatable, Sendable {
    case none
    case placed(count: Int)
    case refused(count: Int)
    case won
}

struct HapticHalf<Content: View>: View {
    let seat: Seat
    let event: SeatEvent
    @AppStorage("haptics") private var hapticsOn = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .sensoryFeedback(trigger: event) { _, new in
                guard hapticsOn else { return nil }
                switch new {
                case .none: return nil
                case .placed: return .impact(weight: .light)
                case .refused: return nil  // both people would feel one person's mistake
                case .won: return .success
                }
            }
    }
}

struct HapticsToggle: View {
    @AppStorage("haptics") private var hapticsOn = true

    var body: some View {
        Toggle("Haptics", isOn: $hapticsOn)
    }
}
```

- **Trigger on a counter, not a flag.** `placed(count:)` changes on every placement, so two placements in a row play twice. A `Bool` that stays `true` plays once.
- **The whole phone vibrates.** A haptic in one half reaches both people. Apple's specs page doesn't describe the haptic hardware, so assume one vibration for the whole device. (unverified for iPhone Duo)
- **Few patterns, each with one meaning.** Apple asks you to use system patterns for their documented meaning and to avoid overuse ([HIG: Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics#Best-practices)). On a shared screen, also skip haptics for one person's mistakes: the other person feels them too.
- **Make them optional.** The HIG asks for a way to turn haptics off. `HapticsToggle` belongs on the setup screen.
- **Check on a device.** The simulator plays no haptics.

## System UI during play

Change these only while play runs, and undo them when it stops.

```swift
import SwiftUI

extension View {
    /// Everything a shared screen changes while play runs, undone when it stops.
    func sharedPlaySession(_ isPlaying: Bool) -> some View {
        self
            .persistentSystemOverlays(isPlaying ? .hidden : .automatic)
            .defersSystemGestures(on: isPlaying ? .all : [])
            .onChange(of: isPlaying, initial: true) { _, playing in
                UIApplication.shared.isIdleTimerDisabled = playing
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
    }
}
```

| Modifier | What it does on a shared screen | Source |
|---|---|---|
| `persistentSystemOverlays(.hidden)` | Asks iOS to keep the home indicator out of the way. A preference: the system might not honour it. *Measured:* our screenshots right after launch still showed the home indicator. | [doc](https://developer.apple.com/documentation/swiftui/view/persistentsystemoverlays(_:)) |
| `defersSystemGestures(on:)` | Your gesture wins the first swipe from those edges. Face to face, the top edge is the first seat's own edge, so a swipe there should move a piece, not pull down a system panel. | [doc](https://developer.apple.com/documentation/swiftui/view/deferssystemgestures(on:)) |
| `isIdleTimerDisabled` | Keeps the screen on during a long turn on a table. Apple asks you to set it back to `false` when you no longer need it. | [doc](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled) |

Leave the status bar alone. The HIG allows layouts that span the full width only when nothing conflicts with the Dynamic Island or the status bar ([HIG: Vertical controls](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls)). Keep controls inside the safe area; let backgrounds extend.

*Measured:* closed and portrait, the safe area left 382 × 644 pt of a 466 × 678 pt window: an 84 pt status bar column on the right and 34 pt at the bottom. Account for that in each half, not by moving the seam.

## Sound

Sound reaches both people, like haptics. Keep it for shared moments (a round starts, someone wins), and follow the same switch-off rule.
