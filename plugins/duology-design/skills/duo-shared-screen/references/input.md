# Input on a shared screen

Touch, turns and controls when two people use one screen. The code builds on the types in [SKILL.md](../SKILL.md): `Seat`, `Facing`, `SeatGate`, `SharedSplit`, `SeatHalf`.

*Measured* means we ran it in a probe app with UI tests on the iPhone Duo simulator (Xcode 27.1, iOS 27.1, a cloned simulator that started closed). *Unverified* means we could not confirm it.

## Tap and drag on one piece

```swift
import SwiftUI

/// A piece its owner can tap or drag. A still finger is a tap; 6 pt of movement is a drag.
struct PieceHalf: View {
    let seat: Seat
    let canAct: Bool
    let onScore: () -> Void
    @State private var dragAt: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            Circle()
                .fill(.tint)
                .frame(width: 64, height: 64)
                .contentShape(Circle())
                .accessibilityElement()  // before .position, so the element is the piece
                .accessibilityLabel("Piece")
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("\(seat.id).piece")
                .position(dragAt ?? CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2))
                .onTapGesture { if canAct { onScore() } }
                .gesture(
                    DragGesture(minimumDistance: 6, coordinateSpace: seat.space)
                        .onChanged { if canAct { dragAt = $0.location.clamped(to: proxy.size) } }
                        .onEnded { _ in
                            if dragAt != nil && canAct { onScore() }
                            dragAt = nil
                        }
                )
        }
    }
}

extension CGPoint {
    /// Keeps a dragged point inside its half.
    func clamped(to size: CGSize) -> CGPoint {
        CGPoint(x: min(max(x, 0), size.width), y: min(max(y, 0), size.height))
    }
}
```

Why it is built this way:

- **`minimumDistance` above zero.** `DragGesture` defaults to 10 pt ([doc](https://developer.apple.com/documentation/swiftui/draggesture/init(minimumdistance:coordinatespace:))). Below that, the touch stays a tap, so `onTapGesture` still fires. *Measured* with 6 pt: a tap counted once and started no drag; a press-and-drag counted once and added no tap. With 0, the drag starts on touch down and can take the touch from the tap (not measured here). Use 0 only on a surface that has no taps, such as a drawing canvas.
- **`coordinateSpace: seat.space`.** The half names its space in `SeatHalf` ([coordinateSpace(_:)](https://developer.apple.com/documentation/swiftui/view/coordinatespace(_:))). Locations then mean the same thing in either half and in either seating. *Measured:* inside a half turned upside down, a screen drag from (38, 48) to (152, 48) arrived as (343, 273) to (229, 273): the owner's coordinates, with no maths in your code.
- **Clamp.** A dragged piece never leaves its half, so it never draws over the other person's side.
- **Accessibility before `.position`.** Applied after it, the element would be the size of the whole half. *Measured:* the piece's element was 64 × 64 pt.
- **`canAct` in the view and the gate in the model.** The view check stops a drag from even starting. The model check is the real one, because a drag can start just before a turn ends.

## Pick, then place

Drags are hard with VoiceOver and Switch Control, and slow in UI tests. Offer a tap path for every drag: tap a piece to pick it, then tap a spot to place it.

```swift
/// Tap a piece to pick it, then tap a spot to place it. Plain Swift, one per seat.
nonisolated struct PickAndPlace<Piece: Hashable & Sendable, Spot: Hashable & Sendable>: Sendable {
    private(set) var picked: Piece?

    /// Tapping the picked piece again drops the pick.
    mutating func tap(piece: Piece) {
        picked = picked == piece ? nil : piece
    }

    /// Returns the move to make, or nil when nothing is picked.
    mutating func tap(spot: Spot) -> (piece: Piece, spot: Spot)? {
        guard let piece = picked else { return nil }
        picked = nil
        return (piece, spot)
    }
}
```

Keep one `PickAndPlace` per seat, so one person's pick never moves the other person's piece.

## Gate every action

`SeatGate` has two modes and a pause:

| Mode | Use it for | The other seat |
|---|---|---|
| `.together` | races, quizzes with a buzzer, drawing side by side | acts at the same time |
| `.takeTurns` | board games, a tutor and a learner taking turns | waits |
| `isPaused` | a pause, the end of a round, a dialog in one half | both wait |

Put the gate in the model and route every change through it:

```swift
import Observation

/// Shared state for both halves. Every change goes through `perform`.
@MainActor
@Observable
final class SharedSession {
    var gate = SeatGate()
    /// Goes up each time a seat completes something. Drives that half's haptic.
    private(set) var successes: [Seat: Int] = [.first: 0, .second: 0]

    func canAct(_ seat: Seat) -> Bool { gate.canAct(seat) }

    /// Runs `action` only if `seat` may act now. `action` returns true when the move counts.
    /// A refused move keeps the turn, unless `failurePassesTurn` says otherwise.
    func perform(_ seat: Seat, failurePassesTurn: Bool = false, _ action: () -> Bool) {
        guard gate.canAct(seat) else { return }
        let succeeded = action()
        if succeeded { successes[seat, default: 0] += 1 }
        if succeeded || failurePassesTurn { gate.finishTurn(of: seat) }
    }
}
```

- **A refused move keeps the turn.** In turn mode, a mis-tap or an illegal move must not hand the turn to the other person. Return `false` from `action` and the same seat goes again.
- **Pass `failurePassesTurn: true` only when a failed try is a turn,** such as a wrong answer in a quiz.
- Check both cases on the Mac ([testing.md](testing.md#rules-on-the-mac)).

Show the waiting side. Dim it, say who goes next, and stop its touches:

```swift
import SwiftUI

extension View {
    /// Dims a half while its seat waits, and says who goes next.
    func waiting(_ isWaiting: Bool, for name: String) -> some View {
        self
            .opacity(isWaiting ? 0.5 : 1)
            .overlay {
                if isWaiting {
                    Text("Waiting for \(name)")
                        .font(.headline)
                        .padding()
                        .background(.regularMaterial, in: Capsule())
                }
            }
            .allowsHitTesting(!isWaiting)
    }
}
```

*Measured* (turn mode): the waiting seat's taps changed nothing; after the first seat played, the second seat could act, and the first could not act twice.

## Two people touching at once

- SwiftUI gestures on separate views in separate halves should run at the same time. (unverified: Device Hub can't send two touches, [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes))
- Never put one gesture over both halves, such as a drag on the whole split. It takes the first touch and the second person waits.
- Test two people at once on a device, both in `.together` mode and while one person drags across the edge of their half.

## Shared and destructive controls

Use `ConfirmInPlaceButton` for Leave, Restart and Reset:

```swift
import SwiftUI

/// A destructive action that confirms inside its half: tap to arm, tap again to act.
/// It disarms after three seconds. No alert, so nothing covers the other person.
struct ConfirmInPlaceButton: View {
    let title: String
    let confirmTitle: String
    let systemImage: String
    let identifier: String
    let action: () -> Void
    @State private var isArmed = false

    var body: some View {
        Button {
            if isArmed { action() }
            isArmed.toggle()
        } label: {
            Label(isArmed ? confirmTitle : title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .tint(isArmed ? Color.red : nil)
        .task(id: isArmed) {
            guard isArmed else { return }
            try? await Task.sleep(for: .seconds(3))
            isArmed = false
        }
        .accessibilityIdentifier(isArmed ? "\(identifier).confirm" : identifier)
    }
}
```

*Measured:* the first tap armed it (the identifier became `second.leave.confirm`), it disarmed by itself after three seconds, and two taps in a row acted once.

Rules:

- **One seat owns it.** Two Leave buttons mean either person can end the session for both. Pick the owner from the use case ([use-cases.md](use-cases.md)): the parent, the tutor, the staff member, or an agreed host in a game.
- **Away from the seam.** The seam is where both people's hands meet. The second seat's bottom edge is far from the seam in every seating, closed or open (see [split-and-seating.md](split-and-seating.md#where-the-seam-is)).
- **Confirm in place, not in an alert.** `rotationEffect` turns only your view's drawing ([doc](https://developer.apple.com/documentation/swiftui/view/rotationeffect(_:anchor:))). System alerts, sheets, menus and the keyboard keep the interface orientation, so face to face the first seat reads them upside down. They also cover both halves. (Reasoned from the API, not tested on the simulator.) The one exception: between rounds, with both seats paused, a system dialog is acceptable for a seat whose half is not turned. While a round runs, never, even from an unturned half: it still covers the other person's side.
- **Pause is shared too.** If either person can pause, either person can resume. Show "Paused by …" in both halves.

## A panel inside one half

Need a picker, a hint or a settings panel during play? Show it inside the half that asked, instead of a sheet across both.

```swift
import SwiftUI

extension View {
    /// Shows `panel` over this half only, in place of a sheet across both halves.
    func halfPanel<Panel: View>(isPresented: Bool, @ViewBuilder panel: () -> Panel) -> some View {
        overlay {
            if isPresented {
                panel()
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.regularMaterial)
                    .transition(.opacity)
            }
        }
    }
}
```

Apply it inside `SeatHalf`, so the panel turns with the half and is clipped to it. Pause that seat (or both, in turn mode) while it shows.

## Typing

The keyboard comes up at the bottom of the screen in the interface orientation (not tested on the simulator). Face to face, that is the wrong way up for the first seat, and stacked it covers the second seat's half.

- Collect names and other text before play, upright, in a normal form.
- During play, use buttons, pickers and choices inside the half.
- If someone must type during play, pause both seats and show the field in an unturned half.
