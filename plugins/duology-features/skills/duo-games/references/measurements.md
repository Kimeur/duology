# What we measured

Every *measured* line in this skill comes from the runs below.

## Method

- **Probe app.** A small SwiftUI app built with `swiftc` against the iOS 27.1 simulator SDK (Xcode 27.1, 27A9275), no Xcode project. It runs the skill's code as published, plus log lines: `GameScreen`, `ArenaScene`, `TouchControls`, `GameLayout`, `ControllerAware`, `MetalGameView` with `Renderer`, a `GCVirtualController` screen and a `TouchOverlay` screen.
- **Device.** The shared "iPhone Duo" simulator, iOS 27.1, 20 October 2026.
- **Poses.** `duo-pose` from `duo-pose-matrix` pressed Device Hub's buttons: Closed, Open, Partially Open (book), then Rotate Right (tabletop). Returning from tabletop to closed passes through Rotate Right three more times, so logs show a few wide and tall sizes in a row there.
- **Evidence.** A log line for every size, fold and controller change, and a screenshot of the display in use after each pose (`xcrun simctl io <UDID> screenshot --display=primary` closed, `--display=primary-1` open).
- **Touch.** UI tests (XCUITest, `xcodebuild test-without-building`) in a project that runs the same code, one run per pose. The scene copies what it reads from `GameInput` into a test label: how far the stick moved, and whether fire was pressed.
- **Caveats.** Other probes shared the simulator. While their UI tests ran, our app was in the background, and one pose change failed; we kept only steps where the log shows the expected size and fold.

## Sizes in each pose

`GameScreen` from SKILL.md, all orientations allowed.

| Pose | Scene | `GameLayout` bounds and safe area insets | Touch controls | Fold seen by `GameScreen` |
|---|---|---|---|---|
| Closed | 466 × 678 pt | 382 × 644 pt; 84 trailing, 34 bottom | 382 × 644 pt | none |
| Open, held wide | 951 × 669 pt | 951 × 635 pt; 34 bottom | 951 × 635 pt | (455.5, 0, 40, 669), inactive |
| Book | 951 × 669 pt | 951 × 635 pt; 34 bottom | 951 × 635 pt | (455.5, 0, 40, 669), active |
| Tabletop | 669 × 455.7 pt | 669 × 917 pt; 34 bottom | 669 × 421.5 pt | (0, 455.5, 669, 40), active |

Reserved regions of kind `.occlusion`, in `GameLayout`'s space:

| Pose | Region | Active |
|---|---|---|
| Closed | (399.7, 29.3, 37, 37): the outer camera | yes |
| Closed | (382, 0, 84, 82): where the status bar sits (our reading) | yes |
| Open, held wide | (677.3, 21, 58, 37): the inner camera | no |
| Tabletop | (611, 677.3, 37, 58): the inner camera, right edge of the bottom region | no |

Key log lines from one run, in order, timestamps removed and the launch line shortened:

```text
launch probe=game ... controllers=0 tcSupported=false
scene didMove id=5854631324630626900 hasCamera=false size=(466.0, 678.0)
GC connect vendor=Gamepad category=MFi attached=false extended=true micro=true class=GCController current=true all=1
scene didChangeSize (466.0, 678.0) -> (669.0, 951.0) id=5854631324630626900
touch controls fold=Optional((0.0, 455.5, 669.0, 40.0)) active=true
touch controls fold=nil active=false
touch controls size=(669.0, 421.5)
scene didChangeSize (669.0, 951.0) -> (669.0, 455.66666666666663) id=5854631324630626900
scene didChangeSize (951.0, 669.0) -> (466.0, 455.66666666666663) id=5854631324630626900
scene didChangeSize (466.0, 455.66666666666663) -> (466.0, 678.0) id=5854631324630626900
scene frames=1200 size=(466.0, 678.0) id=5854631324630626900
```

- The scene id is the same on every line of a run; `didMove(to:)` appears once per launch.
- Each `didChangeSize` line appears twice in the raw log (one copy shown).
- The touch controls first see the fold of the whole screen, then `nil` once `GameLayout` has moved them below it.
- A last run with the published `GameScreen` counted 300 frames every 5 s from launch to the end, through closed, open, book, tabletop and closed again: 6,000 frames, one scene, one `didMove(to:)`.

## Touch, by UI test

Each test launches the game, waits for the fire button, then touches. "Moved" means the stick reached more than 0.3 to the right.

| Pose | Touch | Result |
|---|---|---|
| Closed | press Fire (centre 330, 592) for 0.8 s | fired |
| Closed | drag right from x = 60 pt | moved, full deflection |
| Book | press Fire (centre 899, 583) | fired |
| Book | drag right from x = 60 pt | moved |
| Book | drag right from x = 445 pt, just left of the fold band | moved |
| Book | drag right from x = 475.5 pt, the fold's centre | nothing |
| Book | drag right from x = 505 pt, just right of the fold band | nothing (the action zone has no stick) |
| Tabletop | press Fire (centre 617, 865) | fired |
| Tabletop | drag right from x = 60 pt, 60 percent down (below the fold) | moved |

The simulator's own "Gamepad" was connected in every test; the fire button stayed visible and hittable.

## Pausing

`SpriteView(scene:isPaused:)` with `isPaused` bound to `session.isPaused || phase != .active`, then the published `GameScreen`, which sets `scene.isPaused` in `onChange`:

| Case | `SpriteView(isPaused:)` | `scene.isPaused` in `onChange` |
|---|---|---|
| UI test launch: the phase went `.inactive`, then `.active` 0.2 s later | 0 frames after 4 s; the log showed `scenePaused=true` after the input turned `false` | about 430 frames after 4 s |
| `session.isPaused` true at launch, false 1 s later | 0 frames after 4 s | about 430 frames after 4 s |
| Home Screen for 3 s, then back | not tested | 377 frames before, 1,136 after |

With `SpriteView(isPaused:)` the scene ran only when the phase was already `.active` at launch. An earlier run launched with `simctl` while another app was in front also stayed frozen, for about three minutes; we didn't isolate what restarted it.

## Touch zones

From an earlier run of the same code that logged `TouchZones` with each size, launched open:

```text
touch controls size=(951.0, 635.0) zones=TouchZones(move: (0.0, 0.0, 475.5, 635.0), act: (475.5, 0.0, 475.5, 635.0))
game fold=Optional((455.5, 0.0, 40.0, 669.0)) active=false
```

The first line is the first layout pass, before any region arrived: the zones split at the middle. Once the fold arrives, `TouchZones` gives movement 0 to 455.5 pt and actions 495.5 to 951 pt.

## Metal

`MetalGameView` with `.ignoresSafeArea()`:

```text
metal drawableSizeWillChange (1398.0, 2034.0) viewBounds=(466.0, 678.0) draws=0
metal drawableSizeWillChange (2853.0, 2007.0) viewBounds=(951.0, 669.0) draws=776
metal drawableSizeWillChange (2007.0, 2853.0) viewBounds=(669.0, 951.0) draws=3098
metal drawableSizeWillChange (1398.0, 2034.0) viewBounds=(466.0, 678.0) draws=4233
metal draws=5100 drawable=(1398.0, 2034.0)
```

No call between open and book: the size didn't change.

## Controllers

- The simulator's "Gamepad" controller connected in all eight launches that logged controllers, 0.02 to 1.4 s after launch, with `controllers=0` at launch.
- `ControllerAware` never logged "controller used" with it, and the fire button showed in every screenshot.
- `GCVirtualController` with a left thumbstick, A and B: `virtual connect error=nil`, then a second controller, `vendor=Apple Touch Controller category=Touch Controller class=GCTouchController`.
- `TCTouchController.isSupported` logged `false` in every launch; `TouchOverlay(view:)` returned `nil`.

## Landscape-only build

The same app with `UISupportedInterfaceOrientations` set to landscape left and right only:

| Pose | Scene | Touch controls | Notes |
|---|---|---|---|
| Closed, held upright | 678 × 466 pt | 594 × 432 pt | The outer display honoured the lock: the game ran sideways. The 84 pt inset moved to the leading or trailing edge. |
| Open, held wide | 951 × 669 pt | 951 × 635 pt | Same as the unlocked build. |
| Book | 951 × 669 pt | 951 × 635 pt | Same. |
| Tabletop | 669 × 455.7 pt, above the fold | 669 × 421.5 pt | The window was 669 × 951 pt: tall, despite the landscape lock. |

So a landscape-only game must still lay out a tall window on the inner display. While the phone closed from tabletop, the closed view reported a fold at x = 182.5 for one pass, then none. Treat every value in the middle of a change as temporary.

## GCVirtualController screenshots

- Book (951 × 669 pt): stick bottom left, A and B bottom right.
- Closed, portrait (466 × 678 pt): A and B near the bottom middle; no stick visible.
- Tabletop, full-window scene (669 × 951 pt): A and B bottom right, below the fold; no stick visible. The scene's play area crossed the fold, because this screen had no `GameLayout`.

Why the stick didn't show in the tall views is unverified.
