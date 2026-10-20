# Game controllers

Every iPhone has a touchscreen; a game controller is an optional extra. Apple asks games to support touch and to treat controllers as an addition, and to show or hide virtual controls as play changes ([HIG: Game controls](https://developer.apple.com/design/human-interface-guidelines/game-controls#Physical-controllers)).

## Show touch controls until a controller is used

```swift
import GameController
import SwiftUI
import TouchController

// requires: GameInput (SKILL.md)

/// Shows the touch controls until the player uses a game controller, and brings
/// them back as soon as the player touches the screen or the controller goes away.
/// Every controller writes into the same GameInput as the touch controls.
struct ControllerAware<Touch: View>: View {
    let input: GameInput
    var onMenu: @MainActor () -> Void = {}
    @ViewBuilder var touchControls: () -> Touch
    @State private var usesController = false

    var body: some View {
        touchControls()
            // Hidden, not removed: a touch still reaches the controls and shows them again.
            .opacity(usesController ? 0 : 1)
            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in usesController = false })
            .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)) { note in
                if let controller = note.object as? GCController { attach(controller) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)) { _ in
                usesController = false
            }
            .onAppear { GCController.controllers().forEach(attach) }
    }

    private func attach(_ controller: GCController) {
        // GCVirtualController and Touch Controller show up as controllers too. They are touch.
        if #available(iOS 26.0, *), controller.productCategory == TCGameControllerProductCategoryTouchController { return }
        guard let pad = controller.extendedGamepad else { return }
        let input = input
        let onMenu = onMenu
        let used = $usesController
        // Handlers run on the main queue unless you set the controller's handlerQueue.
        pad.valueChangedHandler = { _, _ in
            MainActor.assumeIsolated { used.wrappedValue = true }   // the player picked it up
        }
        pad.leftThumbstick.valueChangedHandler = { _, x, y in
            MainActor.assumeIsolated { input.move = CGVector(dx: CGFloat(x), dy: CGFloat(y)) }
        }
        pad.buttonA.pressedChangedHandler = { _, _, pressed in
            MainActor.assumeIsolated { input.isFiring = pressed }
        }
        pad.buttonMenu.pressedChangedHandler = { _, _, pressed in
            if pressed { MainActor.assumeIsolated { onMenu() } }
        }
    }
}
```

- **Wait for input, not for a connection.** A controller can be connected and unused: in a bag, on the table, or the simulator's own (below). The profile's `valueChangedHandler` fires for any button or stick, so the first press hides the touch controls.
- **Hidden, not removed.** The controls keep their place and their touches. The first touch both works and shows them again.
- **One input.** Touch and controllers write the same `GameInput`, so the scene never knows which one the player holds.
- **Menu pauses.** Apple maps the Menu button to settings or pause ([HIG: Game controls](https://developer.apple.com/design/human-interface-guidelines/game-controls#Physical-controllers)). Pass `onMenu` to pause the session.
- **Main actor.** The handlers run on the main queue by default (`handlerQueue`), so `MainActor.assumeIsolated` holds. If you move them to another queue, hop to the main actor instead.
- **Folding doesn't touch controllers.** Nothing here depends on the pose. The controllers stay attached through fold and unfold; only the views move.

## The simulator's own controller

*Measured* on the iPhone Duo simulator (Xcode 27.1, iOS 27.1), in all eight probe launches that logged controllers on 20 Oct 2026, with no game controller connected to the Mac:

| Property | Value |
|---|---|
| `GCController.controllers()` at launch | empty |
| `GCControllerDidConnect`, 0.02 to 1.4 s after launch | one controller |
| `vendorName` | "Gamepad" |
| `productCategory` | "MFi" |
| `isAttachedToDevice` | `false` |
| `extendedGamepad`, `microGamepad` | both present |
| `GCController.current` | that controller |

- A game that hides its touch controls as soon as a controller connects would hide them on every simulator launch, and UI tests would find no controls.
- With `ControllerAware`, the touch controls stayed visible on every run: the simulator's controller sent no input (*measured*).
- Where it comes from is unverified (our guess: the simulator's own input bridge). Whether a real iPhone Duo reports anything similar is unverified.

## On-screen controllers count too

*Measured:* a connected `GCVirtualController` added a second controller with the vendor name "Apple Touch Controller" and the product category "Touch Controller", the value of `TCGameControllerProductCategoryTouchController` (Touch Controller framework, iOS 26). `ControllerAware` skips it, so playing with the on-screen controller never hides your own touch controls. If the virtual controller *is* your touch control, drop `ControllerAware` and hide the virtual one when a real controller is used.

## Two controllers

For two players with two controllers:

- Seat a controller when it is first used, not when it connects: the simulator's controller connects at launch and would take player 1.
- Set `playerIndex` (`.index1`, `.index2`). Some controllers show it with lights; Apple's header says not all do ([`playerIndex`](https://developer.apple.com/documentation/gamecontroller/gccontroller/playerindex)).
- Give each player their own `GameInput`, and keep touch for both halves. The two-player frame is in `recipe-two-player-game` and `duo-shared-screen`.
- Label buttons with the symbols of the controller each player holds ([HIG: Game controls](https://developer.apple.com/design/human-interface-guidelines/game-controls#Physical-controllers)).

## Controller events and focus

`handlesGameControllerEvents(matching:)` (iOS 18) tells SwiftUI to send controller events to the Game Controller framework while the view, or one inside it, has focus. Apple's example puts it on a `SpriteView` ([doc](https://developer.apple.com/documentation/swiftui/view/handlesgamecontrollerevents(matching:))). The UIKit counterpart is `GCEventInteraction` on the view that hosts your Metal layer ([doc](https://developer.apple.com/documentation/gamecontroller/gceventinteraction)). We did not test what changes without them on iPhone Duo (unverified).
