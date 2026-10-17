# Evidence: what we ran for this skill

Every *measured* line in `duo-testing` comes from the runs on this page. Re-run them when Xcode or the iOS runtime changes, and update the skill's `verified:` line.

## Setup

- Mac: macOS 27.0.1, Apple silicon. Xcode 27.1 (27A9275) at `/Applications/Xcode-27.1.app`, used through `DEVELOPER_DIR`. Swift 6.4.
- Simulator: a private iPhone Duo created for these runs (`simctl create`, iOS 27.1 runtime 24A94425), deleted afterwards. We did not use the shared "iPhone Duo" simulator, because other work was running on it.
- Pose: the new simulator booted **closed** and stayed closed. The app ran on the outer display, in portrait. `onHingeChange` reported `closed`. No API changes the pose, so nothing here was run open or partly open.
- Control: an iPhone 17 Pro simulator on iOS 27.0 (24A434), created and deleted the same way.
- Date: 16 October 2026.

## 1. Logic tests on the Mac

| Run | Result |
|---|---|
| `Tools/run-logic-tests.sh` (swiftc, Swift 6, macOS) | 5 `ok` lines, "All checks passed.", exit 0 |
| Same, with one expectation broken | `FAIL outer-display width fits two columns (main.swift:23)`, exit 1 |
| `main.swift` without `@MainActor` on `check` | compile error: main actor-isolated var 'failures' can not be mutated from a nonisolated context |
| `GridPlan.swift`, `swiftc -typecheck -default-isolation MainActor` for the iOS 27.1 simulator | no errors |
| `xcrun swift test` in the `AppCore` package | 3 tests in 1 suite passed (one test with 4 argument cases), about 14 s from clean |

## 2. Probe app: which touches reach SwiftUI

A SwiftUI probe app with a tap target (`onTapGesture`), a button, a drag source (`DragGesture(minimumDistance: 6)`) and drop target, a pinch target (`MagnifyGesture`), and a readout of its size, size class and hinge status. Each element exposed its counts through `accessibilityValue`, behind `-uiTesting`. 17 UI tests over three runs, each from a fresh launch.

Geometry, closed, portrait:

| What | Value |
|---|---|
| `app.frame` and the window frame | 0, 0, 466 × 678 pt |
| `GeometryReader` inside a `NavigationStack` | 382 × 562 pt, origin 0, 82 |
| Horizontal size class | compact |
| `XCUIScreen.screens.count` | 2 |
| `XCUIScreen.main` screenshot | 466 × 678 pt at scale 3 |
| `screens[0]` / `screens[1]` screenshots | 466 × 678 pt / 668.67 × 950.67 pt |

The 466 × 678 pt window confirms the closed window size that `reference/device-facts.md` lists as derived.

Touches (all reached the gesture; counts read from `accessibilityValue`):

| Call | Read back |
|---|---|
| `element.tap()` | taps=1 |
| `element.coordinate(withNormalizedOffset: (0.5, 0.5)).tap()` | taps=1 |
| `app.coordinate(withNormalizedOffset: (0.41, 0.41)).tap()`, the element's centre worked out from `app.frame` | taps=1 |
| `app.coordinate(withNormalizedOffset: .zero).withOffset((191, 281)).tap()` | taps=1 |
| `press(forDuration: 0.3, thenDragTo:)`, element to element coordinates | drags=1, dx=270 |
| `press(forDuration: 0.01, thenDragTo:)`, element coordinates | drags=1, dx=270 |
| `press(forDuration: 0.3, thenDragTo:)`, app coordinates | drags=1, dx=270 |
| `press(forDuration: 0.3, thenDragTo:, withVelocity: .slow, thenHoldForDuration: 0.2)` | drags=1, dx=270 |
| `element.press(forDuration: 0.3, thenDragTo: element)` | drags=1, dx=270 |
| `element.swipeRight()` | drags=1, dx=80 |
| `element.pinch(withScale: 2, velocity: 1)` | pinches=1, scale 3.58 |

Launch switches:

| Test | Result |
|---|---|
| Launch without `-uiTesting` but with `-openScreen` | app opened at home; no marker or test ID in the tree |
| Launch counter in `@AppStorage`, three launches: reset, no reset, reset | 1, 2, 1 |

## 3. What the shipped app's suite found

A two-player game built for iPhone Duo (private, not named here) has about 20 UI tests that drag blocks, tap through screens and type names. Its helpers carry two comments: taps placed relative to the app don't reach it on the iPhone Duo simulator while taps relative to an element do; and a slow drag from app-relative points doesn't reach SwiftUI's `DragGesture` while a `press(forDuration: 0.3, thenDragTo:)` between element coordinates does. That suite passed on the shared iPhone Duo simulator. Another probe on that simulator reported the hinge `fullyOpen` minutes before one of its runs, so it most likely ran open, on the inner display.

Our closed-pose probe did not reproduce the failures. Two readings fit: the problem appears only open, on the inner display; or it depended on something in that app. We could not test the first, because no API opens the simulator. *Unverified* until someone runs the pose probe below open.

## 4. Rotation from a UI test

`XCUIDevice.shared.orientation` set to landscape left, portrait, landscape right, portrait. After each, the test waited up to 8 s for the app's own size readout to change.

| Simulator | App after landscape | Screenshot | Device orientation read back |
|---|---|---|---|
| iPhone Duo, iOS 27.1, closed | still 466 × 678 pt; readout unchanged | 466 × 678 (portrait) | the new value |
| iPhone 17 Pro, iOS 27.0 (control) | 874 × 402 pt; readout changed | 874 × 402 | the new value |

The probe's Info.plist allowed portrait, landscape left and landscape right. Same build for both runs (deployment target 27.0).

## 5. The sample in `ui-tests.md`

The sample app and `BoardUITests` built with Swift 6, a deployment target of iOS 26.0 and main-actor default isolation on the app target, with no warnings. All tests passed on the Duo simulator, closed. Run with `Tools/run-ui-tests.sh` from [commands.md](commands.md).

| Check | Result |
|---|---|
| 4 tests in `BoardUITests` | passed, about 33 s |
| `tearDown()` override in a class without `@MainActor`, calling a main-actor helper | compile error: sending 'self' risks causing data races |
| Same, with `@MainActor` on the class | compiled, no warnings |
| Forced failure: attachments | `display-0` 1398 × 2034 px, `display-1` 2006 × 2852 px, plus a screen recording and a "Synthesized Event" attachment |
| `simctl io <UDID> screenshot --display=primary-1` on the same simulator, after the run | 2007 × 2853 px (outer, `--display=primary`: 1398 × 2034 px) |
| Runner script on pass / fail | exit 0 / exit 65 with the `FAIL` line and message |

## 6. xcodebuild timing and errors

| Run | Observed |
|---|---|
| `xcodebuild test` on a just-created Duo simulator | "Timed out trying to boot simulator after waiting 60.00s", exit 65 |
| `simctl bootstatus -b` on it afterwards | booted in about 60 s |
| 14 passing probe tests | last test 20:44:21, exit 20:44:21 |
| 1 failing test, default flags | test ended 21:10:57; "Failure collecting diagnostics from simulator: Timed out after 600.0 seconds" at 21:20:57; then exit 65; bundle 50 MB |
| 1 failing test, `-collect-test-diagnostics never` | failed and exited at 21:22:18; bundle 1.1 MB |
| `simctl create` iPhone 17, 17e, 17 Pro, Air, 18 Pro or 18 Pro Max on iOS 27.1 | "Incompatible device" each time |
| `build-for-testing` with `-destination "platform=iOS Simulator,name=iPhone Duo"` | built |

## The pose probe: settle the open case

Run this once the simulator is open. It passes closed (*measured*).

1. Create and boot your own Duo simulator (see [commands.md](commands.md)).
2. Open Device Hub, select that simulator, click **Open** under the bezel.
3. Add this test to `BoardUITests` and run only it with `-only-testing:AppUITests/BoardUITests/testAppRelativeTapReachesTheApp`.

```swift
/// Pose probe: run it once closed and once open (Device Hub > Open) to see whether
/// taps placed relative to the app reach it. Element-relative taps are the safe default.
func testAppRelativeTapReachesTheApp() {
    let app = launch(["-openScreen", "board"])
    let tile = element(app, "board.tile")
    XCTAssertTrue(tile.waitForExistence(timeout: 10))
    let frame = app.frame
    let offset = CGVector(dx: (tile.frame.midX - frame.minX) / frame.width,
                          dy: (tile.frame.midY - frame.minY) / frame.height)

    app.coordinate(withNormalizedOffset: offset).tap()

    XCTAssertEqual(fields(tile)["taps"], "1", "app-relative tap at \(offset), app frame \(frame)")
}
```

4. If it fails open, the workaround is pose-specific: update the table in `SKILL.md` and this page. If it passes open, the shipped app's failures came from something else; say so here.
