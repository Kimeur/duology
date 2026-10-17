# Architecture of the two-player recipe

How the generated project fits together, why each piece is where it is, and what we ran to check it. Paths use `<App>` for the app name you gave `new-project.sh`.

## The layers

```text
RootView                         owns DuelSetup and the DuelModel (survives every layout change)
 └─ DuelScreen                   overlays hidden, edge gestures deferred, idle timer off, clock task
     └─ EvenSplit                side by side when wide, stacked when tall (AnyLayout)
         ├─ PlayerHalf(.one)     turned 180° in face-to-face mode
         │   ├─ PlayField        coordinate space "p1.field"
         │   │   ├─ touch surface   Color.clear + contentShape + SpatialTapGesture
         │   │   └─ content         ReadyPanel | countdown | TargetView | ResultPanel
         │   └─ ScoreBar         score, misses, time left
         └─ PlayerHalf(.two)     never turned; its ScoreBar holds the leave button
```

The engine (`<App>/Engine/`) sits under all of it and imports only Foundation.

## One touch, start to finish

1. A finger lands in player 2's field. The touch surface's `SpatialTapGesture(coordinateSpace: .named("p2.field"))` reports the location in that field's own coordinates. If the half is turned, SwiftUI undoes the turn for you.
2. `PlayField` calls `model.tap(.two, at: GamePoint(location), in: area)`. `area` is the field's play area, worked out in the same coordinates (next section).
3. `DuelModel.tap` stamps the time and calls `Duel.tap(_:at:in:now:)`.
4. `Duel.tap` first runs `tick(now:)`, so a round whose time ran out ends before the touch counts. Then `canTap` gates it: wrong phase, or locked out after a miss, returns `.ignored`.
5. The engine maps the player's current `Spot` (fractions 0...1) into `area`, tests the distance with `hitSlop`, and returns `.hit`, `.miss` or `.won`. A miss sets `lockedUntil`.
6. `DuelModel` bumps `hitCount[.two]` or `missCount[.two]`. Player 2's `.sensoryFeedback` fires on that counter only.
7. Views read `model.duel` and redraw: the target moves, the score changes, or the result panels appear.

The views never decide who scored. That keeps the rules testable without a simulator.

## The clock

`DuelScreen` starts `model.runClock()` in `.task`, so it stops when the screen goes away. It ticks ten times a second:

- `now` changes every tick, so the countdown and the time left redraw;
- `duel` is written only when `tick` changed it (`Duel` is `Equatable`), so views that read only the scores don't redraw ten times a second.

The engine takes `now` as a parameter everywhere. Tests pass fixed dates and never sleep.

## The play area

`FoldAvoidance.playArea(in:margin:)` runs inside `onGeometryChange(for:of:action:)`, whose transform closure is `@Sendable`, so the function and the geometry bridge are `nonisolated`.

1. Start from the field's bounds, inset by a 12 pt margin.
2. On iOS 27.1 and later, ask the proxy for `reservedRegions(kind: .division)` and `reservedRegions(kind: .occlusion)`, and keep the active ones. Earlier systems, and phones that don't fold, return none.
3. For each region that touches the area, try the strips left of, right of, above and below it (each grown by the margin). Keep the strip with the longest short side.
4. A target's radius is `max(minTargetRadius, targetShare × short side)`, capped at half the short side. Its centre maps into the area shrunk by the radius, so the whole circle stays inside.

Why not split exactly on the fold instead: the fields sit inside the safe area, so a half's edge is not always on the fold. Avoiding the regions works wherever the seam lands. If your game needs the seam on the fold, use `FoldSplitLayout` from `duo-layout` (references/custom-split.md).

Apple's sources: [ReservedRegion](https://developer.apple.com/documentation/swiftui/reservedregion), [reservedRegions(kind:options:layoutDirectionBehavior:)](https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:)), and Tech Talk [111463](https://developer.apple.com/videos/play/tech-talks/111463/). Not yet run with an active fold (unverified).

## Engine API

| Member | What it does |
|---|---|
| `Duel(rules:seed:)` | A duel in `.waiting`. The same seed replays the same targets. |
| `subscript(player)` | That player's `PlayerState`: hits, misses, ready, locked until. |
| `toggleReady(_:now:)` | Ready or not ready. Both ready starts a round (round 1, or a rematch). |
| `tick(now:)` | Countdown to playing; playing to finished when time runs out. |
| `canTap(_:now:)`, `isLocked(_:now:)` | Input gating. |
| `spot(for:)`, `target(for:in:)` | The current target, as fractions or as a circle in an area. |
| `tap(_:at:in:now:)` | Judges a touch; returns `.hit`, `.miss`, `.won` or `.ignored`. |
| `countdownRemaining(now:)`, `timeRemaining(now:)` | For the countdown and the clock. |
| `outcome`, `reset()` | Who won; back to the start. |
| `PlayArea.fit(_:avoiding:margin:)` | The area math above. |
| `SeededGenerator` | SplitMix64, the same on every platform. |

Every type is `nonisolated` and `Sendable`. The app target compiles with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so without `nonisolated` the engine would be main-actor code. The engine test build uses the same setting and runs one check in `Task.detached`; drop a `nonisolated` and it stops compiling.

## Accessibility and identifiers

- Each half is a container labelled "Player 1" or "Player 2" (`p1.half`, `p2.half`). Each field is a container too (`p1.field`).
- The target is a button labelled "Target" (`p1.target`). VoiceOver's activate runs `activateTarget`, which taps the target's centre through the engine.
- Score: `p1.score`, label "Player 1, 2 of 10 hits". Others: `p1.misses`, `p1.clock`, `p1.locked`, `p1.countdown`, `p1.ready`, `p1.prompt`, `p1.result`, `p1.rematch`, `duel.leave`, `home.start`, `home.goal`, `home.faceToFace`.

*Measured* on the iPhone Duo simulator: with `.contentShape(Rectangle())` and the tap gesture on the field container, the target's accessibility frame was the whole field (382 × 261 pt) instead of the circle (56 × 56 pt). Removing `.contentShape` fixed the target but shrank the field's frame to its content. A clear touch layer beside the content, with `.allowsHitTesting(false)` on the target, gave both the right frames, and taps still scored. `.position` was not the cause: it works once the container has no content shape.

## Launch switches

Debug builds only (`#if DEBUG`). The last copy of a switch wins, so a test can override defaults.

| Switch | Effect |
|---|---|
| `-uiTesting` | Animations off. |
| `-openDuel` | Skip the home screen. |
| `-autoReady` | With `-openDuel`: both players ready, the round starts. |
| `-faceToFace` | Turn player 1's half. |
| `-goal N`, `-countdown N`, `-lockout N`, `-timeLimit N` | Rules. `-timeLimit 0` means no limit. |
| `-seed N` | Fixed targets. |

## The UI tests

| Test | Checks |
|---|---|
| `testHomeStartsADuel` | Start opens both halves. |
| `testBothPlayersMustBeReady` | One ready is not enough; both start the countdown. |
| `testTapsDuringTheCountdownDoNothing` | Countdown taps are not hits, misses or lockouts. |
| `testHitsCountInEachHalf` | Hits count for the right player only. |
| `testMissLocksOnlyThatPlayer` | A miss locks one player; the other still scores; the lock ends. |
| `testFirstToTheGoalWinsThenRematch` | Winner and loser panels; rematch needs both; scores reset. |
| `testTimeLimitCanEndInATie` | The clock shows; time up with equal hits is a tie. |
| `testTurnedHalfStillScores` | Hits and misses in the turned half. |
| `testLeavingAsksFirst` | Leave asks, then goes home. |
| `testBothHalvesShowInThisPose` | Split along the long side, equal fields, target frame is the circle; saves a screenshot. |

Duo simulator notes:

- Tap through `element.coordinate(withNormalizedOffset:)`. An earlier Duo app's UI tests found that taps at points worked out from the app's frame could miss the app (not re-checked here; element coordinates worked in every run below).
- A miss taps the field corner farthest from the target, worked out from both frames.
- *Measured:* `XCUIDevice.shared.orientation = .landscapeLeft` on the closed Duo simulator changed the reported orientation, but the window was still 466 × 678 pt after 8 s and a screenshot showed the portrait layout. Rotate in Device Hub instead. On an iPhone 17 simulator (iOS 26.2) the same call did turn the app.

## Drag instead of tap

Swap the touch surface's gesture. Keep `coordinateSpace:` so drags arrive in the field's coordinates.

```swift
import SwiftUI

/// A touch surface that reports a drag in the field's own coordinates.
struct DragSurface: View {
    let space: NamedCoordinateSpace
    let onMove: (GamePoint) -> Void
    let onDrop: (GamePoint) -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: space)
                    .onChanged { onMove(GamePoint($0.location)) }
                    .onEnded { onDrop(GamePoint($0.location)) }
            )
    }
}
```

In UI tests, drag with `press(forDuration: 0.3, thenDragTo:)` between element coordinates ([doc](https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/press(forduration:thendragto:))). An earlier Duo app's UI tests found that quicker drags didn't reach a SwiftUI `DragGesture` on the Duo simulator. This recipe's own tests don't drag, so that is not re-checked here.

## Taking turns

Keep turn order in the engine and gate on it, so the view stays the same.

```swift
import Foundation

/// Whose turn it is. Add one to `Duel`, check it in `canTap`, and call `pass()` after a move.
nonisolated struct TurnGate: Equatable, Sendable {
    private(set) var current: Player = .one

    func allows(_ player: Player) -> Bool {
        player == current
    }

    mutating func pass() {
        current = current.other
    }
}
```

In `Duel.canTap(_:now:)`, add `turns.allows(player)` to the guard. Dim the half that is waiting, and say whose turn it is in both halves.

## What we ran

| Check | Result |
|---|---|
| `Tools/run-engine-tests.sh` (Mac, Swift 6.4, `-default-isolation MainActor`) | 59 passed, 0 failed |
| `swiftc -typecheck` of the app sources, targets iOS 27.1 and iOS 26.0 simulator | no errors, no warnings |
| `xcodebuild build-for-testing`, iPhone Duo simulator (iOS 27.1) | succeeded, no compiler warnings |
| Launch and screenshots, closed (outer display), home, waiting, playing, face to face | looked at; both halves fill the display, content clear of the status bar column |
| `Tools/run-ui-tests.sh`, iPhone Duo simulator, closed | 10 passed (128 s) |
| A failing run with test diagnostics on, then off | 720 s and 138 s in total for about 120 s of tests, hence `-collect-test-diagnostics never` |
| Same tests plus a rotation check, iPhone 17 simulator, iOS 26.2 | 11 passed; sideways the fields sat side by side (374 × 322 pt each) and the score survived the turn |

## Not yet verified

- The open pose (inner display), partly open, and Split View on the Duo simulator: poses change only in Device Hub, and these runs used a closed simulator.
- An active fold region, so `PlayArea` avoiding a real fold (its math is tested on the Mac).
- Fold and unfold during a round.
- Two people touching at once, and haptics, on a real iPhone Duo.
