# UI tests on the iPhone Duo simulator

A complete, small sample: an app with launch switches and test markers, and a UI test class that drags, taps and reads state. Build it from the four files below, exactly as listed. It builds with Xcode 27.1 at a deployment target of iOS 26.0, Swift 6, with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` on the app target, with no warnings. Its 4 UI tests passed on the iPhone Duo simulator (iOS 27.1, closed) on 16 October 2026, and again on 17 October when a reviewer rebuilt the app from these listings alone (5 of 5 with the pose probe in [evidence.md](evidence.md)).

Files:

```
App/
  TestSupport.swift      launch switches + test markers (SKILL.md, sections 2 and 3)
  SampleApp.swift        App and RootView, as in SKILL.md section 2 (RootView opens BoardView)
  BoardView.swift        the screen under test (below)
AppUITests/
  BoardUITests.swift     the tests (below)
```

The UI test target sets `SWIFT_VERSION = 6.0` and `TEST_TARGET_NAME` to the app. Like Xcode 27.1's UI test template, it sets no default actor isolation (only the app template sets `MainActor`).

## The screen under test

One piece to drag into a slot, a tile to tap, a round counter and a button. The view keeps its state in `@State` to stay short; in a real app the rules would live in a plain-Swift model tested on the Mac ([logic-tests.md](logic-tests.md)).

```swift
import SwiftUI

/// One piece to drag into a slot, a tile to tap, and a button. Small on purpose.
struct BoardView: View {
    @State private var placed = false
    @State private var moves = 0
    @State private var taps = 0
    @State private var round = 1
    @State private var slotFrame = CGRect.zero
    @GestureState private var dragOffset = CGSize.zero

    var body: some View {
        VStack(spacing: 32) {
            Text("Round \(round)")
                .testID("board.round")

            RoundedRectangle(cornerRadius: 12)
                .fill(.mint)
                .frame(width: 200, height: 80)
                .onTapGesture { taps += 1 }
                .testMarker("board.tile", value: "taps=\(taps)")

            HStack {
                Circle()
                    .fill(placed ? .green : .orange)
                    .frame(width: 70, height: 70)
                    .offset(dragOffset)
                    .gesture(drag)
                    .testMarker("board.piece", value: "placed=\(placed ? 1 : 0)|moves=\(moves)")
                Spacer()
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.secondary, lineWidth: 2)
                    .frame(width: 90, height: 90)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("board")) } action: { slotFrame = $0 }
                    .testMarker("board.slot")
            }
            .frame(maxWidth: 360)

            Button("Next round") {
                round += 1
                placed = false
            }
            .testID("board.next")
        }
        .padding()
        .coordinateSpace(.named("board"))
        .navigationTitle("Board")
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("board"))
            .updating($dragOffset) { value, offset, _ in offset = value.translation }
            .onEnded { value in
                moves += 1
                placed = slotFrame.contains(value.location)
            }
    }
}
```

Things to copy from it:

- `testMarker` goes after the gesture and the frame, so the element's frame is the view's real hit area.
- The value names the state a test checks (`placed`, `moves`), not how the view looks.
- The slot has a marker too. The test drags to an element; it never computes where the slot is.

## The test class

```swift
import XCTest

/// XCUIAutomation types belong to the main actor, so the whole class does too.
@MainActor
final class BoardUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// On failure, keep a screenshot of each display (outer and inner) in the result bundle.
    override func tearDown() async throws {
        if testRun?.hasSucceeded == false { attachDisplays() }
    }

    func testDragPieceIntoSlot() {
        let app = launch(["-openScreen", "board"])
        let piece = element(app, "board.piece")
        let slot = element(app, "board.slot")
        XCTAssertTrue(piece.waitForExistence(timeout: 10))

        drag(piece, onto: slot)

        XCTAssertEqual(fields(piece)["placed"], "1", "the piece lands in the slot")
        XCTAssertEqual(fields(piece)["moves"], "1")
    }

    func testTapInsideAShape() {
        let app = launch(["-openScreen", "board"])
        let tile = element(app, "board.tile")
        XCTAssertTrue(tile.waitForExistence(timeout: 10))

        tile.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()   // left part of the tile

        XCTAssertEqual(fields(tile)["taps"], "1")
    }

    func testNextRoundResetsThePiece() {
        let app = launch(["-openScreen", "board"])
        let piece = element(app, "board.piece")
        XCTAssertTrue(piece.waitForExistence(timeout: 10))
        drag(piece, onto: element(app, "board.slot"))
        XCTAssertEqual(fields(piece)["placed"], "1")

        app.buttons["board.next"].tap()

        XCTAssertTrue(app.staticTexts["board.round"].wait(for: \.label, toEqual: "Round 2", timeout: 3))
        XCTAssertTrue(waitForValue(piece, containing: "placed=0"), "a new round starts with the piece out")
    }

    func testWithoutSwitchesTheAppStartsAtHome() {
        let app = XCUIApplication()
        app.launchArguments = ["-openScreen", "board"]          // no -uiTesting: ignored
        app.launch()
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "home.play").exists, "no test identifiers without -uiTesting")
    }

    // MARK: Helpers

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetState"] + extra
        app.launch()
        return app
    }

    /// Finds any element by identifier: buttons, texts and test markers alike.
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Reads a test marker's value, "key=value|key=value", into a dictionary.
    private func fields(_ element: XCUIElement) -> [String: String] {
        var result: [String: String] = [:]
        for part in (element.value as? String ?? "").split(separator: "|") {
            let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
            if pair.count == 2 { result[pair[0]] = pair[1] }
        }
        return result
    }

    /// Waits until a marker's value contains some text, for state that changes after an animation or a timer.
    private func waitForValue(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", text), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func attachDisplays() {
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let attachment = XCTAttachment(screenshot: screen.screenshot())
            attachment.name = "display-\(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    /// Press, hold, then drag. Both ends are relative to elements, never to the app.
    private func drag(_ element: XCUIElement, onto target: XCUIElement, hold: TimeInterval = 0.3) {
        let center = CGVector(dx: 0.5, dy: 0.5)
        element.coordinate(withNormalizedOffset: center)
            .press(forDuration: hold, thenDragTo: target.coordinate(withNormalizedOffset: center))
    }
}
```

Notes on the class:

- **Isolation.** XCUIAutomation marks `XCUIApplication`, `XCUIElement`, `XCUICoordinate` and `XCUIDevice` as main-actor types (the `XCUI_SWIFT_MAIN_ACTOR` attribute in the Xcode 27.1 headers). Xcode's template puts `@MainActor` on each test method. That is enough until a nonisolated override such as `tearDown` touches them. *Measured:* calling a main-actor helper from `tearDown()` in an unannotated class failed with "sending 'self' risks causing data races"; with `@MainActor` on the class, the async `tearDown()` override compiled with no warnings.
- **`continueAfterFailure = false`.** A UI test that goes on after a failed step only produces noise.
- **One element finder.** `descendants(matching: .any).matching(identifier:)` finds buttons, static texts and markers alike, so tests don't break when a marker changes element type.
- **`firstMatch`.** The XCUIAutomation header says it stops searching at the first match, which can be much faster, and that it won't notice duplicates. Keep identifiers unique on a screen.
- **Failure screenshots.** `XCUIScreen.screens` lists both displays ([Apple](https://developer.apple.com/documentation/xcuiautomation/xcuiscreen/screens)). *Measured:* after a forced failure, the bundle held `display-0` at 1398 × 2034 px and `display-1` at 2006 × 2852 px. Xcode also kept a screen recording and a "Synthesized Event" attachment for the failing test without being asked. `xcresulttool export attachments --only-failures` skipped the two display shots, because they are added in `tearDown`, not at the failing line; export without that flag.
- **Not App Store screenshots.** The inner shot from `XCUIScreen` came out at 2006 × 2852 px. `xcrun simctl io <UDID> screenshot --display=primary-1` gave 2007 × 2853 px, the size App Store Connect asks for ([screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)). Use `simctl` or Device Hub for store screenshots.

## Gestures that reached SwiftUI

*Measured* on the iPhone Duo simulator, closed (outer display), portrait, with a probe app. Each row ran in its own test, from a fresh launch.

| Call | Gesture in the app | Result |
|---|---|---|
| `element.tap()` | `onTapGesture` | reached |
| `element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()` | `onTapGesture` | reached |
| `app.coordinate(withNormalizedOffset:)` at the element's centre, from `app.frame` | `onTapGesture` | reached |
| `app.coordinate(withNormalizedOffset: .zero).withOffset(_:)` to the element's centre | `onTapGesture` | reached |
| `press(forDuration: 0.3, thenDragTo:)`, element coordinates | `DragGesture(minimumDistance: 6)` | reached, 270 pt |
| `press(forDuration: 0.01, thenDragTo:)`, element coordinates | `DragGesture` | reached |
| `press(forDuration: 0.3, thenDragTo:)`, app coordinates | `DragGesture` | reached |
| `press(forDuration:thenDragTo:withVelocity: .slow, thenHoldForDuration: 0.2)` | `DragGesture` | reached |
| `element.press(forDuration: 0.3, thenDragTo: otherElement)` | `DragGesture` | reached |
| `element.swipeRight()` | `DragGesture` | reached, 80 pt |
| `element.pinch(withScale: 2, velocity: 1)` | `MagnifyGesture` | reached |

What a shipped two-player Duo app's suite found, most likely with the phone open: taps placed relative to the app, and slow drags between app-relative points, did not reach the app; the element-relative forms in the sample above did. We could not put the probe in the open pose from code, so that half is *unverified* here. The sample uses only forms that worked in both.

## Rotation and poses

- `XCUIDevice.shared.orientation` exists for UI tests ([Apple](https://developer.apple.com/documentation/xcuiautomation/xcuidevice/orientation)).
- *Measured:* on the closed Duo simulator it did not rotate the app. After setting `.landscapeLeft` and `.landscapeRight`, the app's frame stayed 466 × 678 pt, the screenshot stayed portrait, and the app's own size readout didn't change within 8 s; only `XCUIDevice.shared.orientation` read back the new value. On an iPhone 17 Pro simulator (iOS 27.0) the same test rotated the app to 874 × 402 pt. The probe allowed portrait and both landscape orientations.
- So, on the Duo, rotate with Device Hub's rotate button (Option-click rotates the other way), as described in [Interacting with your app in Device Hub](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub). Open pose not measured.
- There is no fold API. `XCUIDevice` has no hinge, pose or display property, and `simctl` and `devicectl` have no pose command in Xcode 27.1. Outside the test, a Mac tool can press Device Hub's pose buttons through the Accessibility API, but only with the user's Accessibility permission (see `duo-setup`). [`duo-pose-matrix`](https://github.com/Kimeur/duology/blob/main/plugins/duology-ship/skills/duo-pose-matrix/SKILL.md) does this from outside the test, not from inside it. So a test that needs a fold waits for a person; `duo-continuity`'s `references/testing.md` has the pattern (skipped unless an environment variable asks for it).

## Patterns worth keeping

- **Jump straight to the screen.** `-openScreen board` costs nothing and saves every test the taps to get there. Keep one test that goes the long way from launch.
- **Timers.** Add a switch such as `-timerSeconds 6` so a test can watch a timer run out in seconds. Wait for the result with `waitForExistence(timeout:)` a little longer than the timer.
- **Countdowns before play.** A switch that skips them beats `Thread.sleep`.
- **Two panes, two players.** Prefix IDs with the pane: `left.piece.a`, `right.piece.a`. Give each pane its own drop-target markers.
- **Typing.** Tap the field, then `typeText(_:)` on the same element.
- **First launch.** The test that checks onboarding passes `-resetState` and no state-seeding switch. Other tests can seed state with a switch so they skip onboarding.
- **Release builds.** All switches sit behind `#if DEBUG`. A test that launches without `-uiTesting` proves the markers and switches stay off.
