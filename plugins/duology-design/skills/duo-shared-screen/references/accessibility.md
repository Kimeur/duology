# Accessibility per half

Two people share one set of accessibility settings. VoiceOver, Dynamic Type and Reduce Motion apply to the whole phone, not to one half. The types come from [SKILL.md](../SKILL.md) and [input.md](input.md).

*Measured* means we ran it in a probe app with UI tests on the iPhone Duo simulator (Xcode 27.1, iOS 27.1). *Unverified* means we could not confirm it.

## One container per person

```swift
import SwiftUI

struct AccessibleHalves: View {
    let firstName: String
    let secondName: String
    @State private var picks: [Seat: PickAndPlace<Int, Int>] = [.first: .init(), .second: .init()]

    var body: some View {
        SharedSplit(spacing: 2) {
            half(.first, name: firstName)
        } second: {
            half(.second, name: secondName)
        }
    }

    private func half(_ seat: Seat, name: String) -> some View {
        SeatHalf(seat: seat, label: "\(name)'s side") {
            VStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { piece in
                    Button("Piece \(piece + 1)") { picks[seat]?.tap(piece: piece) }
                        .accessibilityAddTraits(picks[seat]?.picked == piece ? .isSelected : [])
                        .accessibilityIdentifier("\(seat.id).piece.\(piece)")
                }
            }
        }
        // VoiceOver reads the first seat's side, then the second's.
        .accessibilitySortPriority(seat == .first ? 1 : 0)
    }
}
```

- **Name each half for its person.** `SeatHalf` makes the half one container with `accessibilityElement(children: .contain)` and a label ([doc](https://developer.apple.com/documentation/swiftui/view/accessibilityelement(children:))). Use the person's name if you have it.
- **Fix the order.** Give the first seat the higher `accessibilitySortPriority(_:)` ([doc](https://developer.apple.com/documentation/swiftui/view/accessibilitysortpriority(_:))), so the order doesn't change when the split turns or flips axis.
- **Selection is a trait.** A picked piece adds `.isSelected`, so VoiceOver says it. `PickAndPlace` is in [input.md](input.md#pick-then-place).

## A tap path for every drag

VoiceOver, Switch Control and Voice Control users can't easily drag. Every drag needs another way in:

- the pick-then-place flow in [input.md](input.md#pick-then-place), or
- a named action on the piece:

```swift
import SwiftUI

struct NudgePiece: View {
    let seat: Seat
    @Binding var column: Int
    let columns: Int

    var body: some View {
        Circle()
            .frame(width: 64, height: 64)
            .accessibilityElement()
            .accessibilityLabel("Piece, column \(column + 1) of \(columns)")
            .accessibilityAction(named: "Move left") { column = max(0, column - 1) }
            .accessibilityAction(named: "Move right") { column = min(columns - 1, column + 1) }
            .accessibilityIdentifier("\(seat.id).nudge")
    }
}
```

`accessibilityAction(named:_:)` adds the action to the VoiceOver actions rotor ([doc](https://developer.apple.com/documentation/swiftui/view/accessibilityaction(named:_:))). In a half turned face to face, "left" means the owner's left, because the action changes the model, not the screen.

## VoiceOver is on for both people

When VoiceOver runs, every touch on the screen goes through it, including the other person's. Two people playing at the same time then gets confusing.

```swift
import SwiftUI

/// Switches to turns while VoiceOver runs, so one person acts at a time.
struct VoiceOverTurns: ViewModifier {
    @Binding var gate: SeatGate
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn

    func body(content: Content) -> some View {
        content.onChange(of: voiceOverOn, initial: true) { _, on in
            if on { gate.mode = .takeTurns }
        }
    }
}
```

- Tell both people: "VoiceOver is on, so you take turns."
- Announce whose turn it is when it changes.
- An option to test with real VoiceOver users: mark the other person's play area as a direct touch area with `accessibilityDirectTouch(_:options:)` ([doc](https://developer.apple.com/documentation/swiftui/view/accessibilitydirecttouch(_:options:))), so their touches reach the app. With `.requiresActivation`, the VoiceOver user activates the area first. We have not tried this with two people. (unverified)

## Turned halves

- *Measured:* XCUITest reported the frames of elements in a turned half as upright boxes around them: a text line in a quarter-turned half came back 39 pt wide and 184 pt tall. VoiceOver's focus rectangle likely does the same. (unverified for VoiceOver)
- Reading order inside a turned half follows its own layout, not the screen. Check it with VoiceOver on a device, face to face. (unverified)

## Text size and motion

- Both halves get the same Dynamic Type size. Test the largest sizes in the smallest half: 382 × 321 pt when closed (*measured*). Wrap text and drop decoration before you clip.
- With Reduce Motion on, change the seating without animating the turn. `SeatingPicker` in [split-and-seating.md](split-and-seating.md#let-people-choose-the-seating) does this.
- Don't use colour alone to tell the halves apart. Add each person's name or a symbol.
