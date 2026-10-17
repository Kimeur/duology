# Testing continuity on the iPhone Duo simulator

Three layers, from cheapest to closest to a real fold:

1. a UI test that flips the size class from inside the app and rotates the simulator;
2. a UI test that waits while you press Closed and Open in Device Hub;
3. a manual pass in Device Hub through the matrix below.

## What Xcode 27.1 can and can't do from code

| Action | From code? | How |
|---|---|---|
| Rotate | From a UI test | `XCUIDevice.shared.orientation` ([orientation](https://developer.apple.com/documentation/xcuiautomation/xcuidevice/orientation)); not yet run on the Duo simulator. From inside the app, *measured:* `requestGeometryUpdate(_:errorHandler:)` on the open inner display failed with "The current windowing mode does not allow for programmatic changes to interface orientation." |
| Close, open, partially open | No | Device Hub buttons only. `XCUIDevice` has no fold or hinge property, and `simctl` has no pose command (checked in Xcode 27.1). |
| Any hinge angle | No | Hold Option and drag the slider under the bezel |
| Split View | No | Drag the app by its home indicator to one side ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)) |
| Size class change | Yes, inside your app | The debug flip below |
| Two-finger gestures | No | Device Hub can't send them (Xcode 27 known issue); test on a device |

## Manual pass in Device Hub

Run the app on the iPhone Duo simulator from Xcode; it opens in Device Hub. The three pose buttons (Closed, Partially Open, Open) sit under the bezel, to the right of the rotate controls. Click the rotate button to rotate left and Option-click it to rotate right ([Interacting with your app in Device Hub](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)). Device > Slow Animations helps you watch each step.

Set up this state first, then run each sequence and check every column after each step:

| Set up | Check after each step |
|---|---|
| Scroll a long list or grid halfway | The same item is at the top |
| Select an item and push one screen in the detail | Same item, same pushed screen; Back still works |
| Type in a field, select a word, keep the keyboard up | Same text, same selection; note what the keyboard does |
| Fill half a form | Every field kept |
| Start video or audio | Still playing, same time, no restart |
| Start an upload | Still running, finishes once |
| Open a sheet | Still open, same content |
| Sign in | Still signed in, no second sign-in screen |

Sequences (each arrow is one button press or rotation):

1. Open → Closed → Open
2. Open → Partially Open → Open
3. Closed portrait → rotate → Open → Closed
4. Open → rotate → Closed → rotate → Open
5. Open → Split View on one side → Closed → Open
6. Open → Closed → Open → Closed → Open, quickly, while scrolling
7. Open → Closed while typing, then Open while typing

Android's large-screen quality tests call these state and combination checks ([adaptive app quality](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality), T-Config_State and T-Config_Combinations). The idea carries over; the rules are Android's.

## The debug flip: app side

A launch switch, ignored in release builds, adds two things at the window root:

- a button that overrides the horizontal size class, so your own size-class code and `NavigationSplitView` take the same path a fold takes;
- hidden labels: a one-line summary of the state that must survive, the current size class, and the root view's size in points.

```swift
import SwiftUI

enum ContinuityTesting {
    #if DEBUG
    static let isOn = ProcessInfo.processInfo.arguments.contains("-continuityTesting")
    #else
    static let isOn = false
    #endif
}

struct ContinuityHarness: ViewModifier {
    let summary: String                                 // built from your model
    @State private var override: UserInterfaceSizeClass?
    @State private var size = CGSize.zero
    @Environment(\.horizontalSizeClass) private var real

    func body(content: Content) -> some View {
        if ContinuityTesting.isOn {
            content
                .environment(\.horizontalSizeClass, override ?? real)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading) {
                        Button("Flip size class") {
                            override = (override ?? real) == .compact ? .regular : .compact
                        }
                        .accessibilityIdentifier("continuity.flip")
                        Text((override ?? real) == .compact ? "compact" : "regular")
                            .accessibilityIdentifier("continuity.sizeClass")
                        Text("\(Int(size.width))x\(Int(size.height))")
                            .accessibilityIdentifier("continuity.windowSize")
                        Text(summary)
                            .accessibilityIdentifier("continuity.summary")
                    }
                    .font(.caption2)
                    .opacity(0.02)                      // present for tests, invisible to people
                }
        } else {
            content
        }
    }
}

extension View {
    func continuityHarness(summary: String) -> some View {
        modifier(ContinuityHarness(summary: summary))
    }
}
```

Use it on the window root, with a summary built from the model:

```swift
import SwiftUI
import Observation

@MainActor @Observable
final class ReaderModel {
    var selection: Int?
    var topItem: Int?
    var draft = ""
    var isPlaying = false

    var summary: String {
        "sel=\(selection.map(String.init) ?? "-") top=\(topItem.map(String.init) ?? "-") "
            + "draft=\(draft.count) playing=\(isPlaying)"
    }
}

struct ReaderRoot: View {
    @State private var model = ReaderModel()
    var body: some View {
        Text("Your root view")
            .environment(model)
            .continuityHarness(summary: model.summary)
    }
}
```

- The `if` in the harness reads a launch switch that never changes while the app runs, so it never changes identity.
- *Measured:* this kind of override made `NavigationSplitView` collapse and expand, and switched `if`/`else` branches, on the iOS 27.1 simulator ([evidence.md](evidence.md)).
- The override changes the size class only. It doesn't move the window to the other display, resize it, or touch the keyboard. Keep the Device Hub pass.
- UIKit: set `traitOverrides.horizontalSizeClass` on the root view controller instead ([traitOverrides](https://developer.apple.com/documentation/uikit/uiviewcontroller/traitoverrides-1z1cc), iOS 17). *Measured:* it ran `registerForTraitChanges` handlers and changed a compositional layout's column count.

## The UI tests

The first test runs anywhere. The second waits for you, so it is skipped unless you ask for it.

```swift
import XCTest

// `nonisolated` keeps XCTestCase's initializers valid when the target defaults to MainActor isolation.
nonisolated final class ContinuityUITests: XCTestCase {
    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-continuityTesting"]
        app.launch()
        return app
    }

    /// Flip the size class, then rotate, and check the summary never changes.
    @MainActor
    func testStateSurvivesSizeClassFlipAndRotation() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launch()
        let summary = app.staticTexts["continuity.summary"]
        let sizeClass = app.staticTexts["continuity.sizeClass"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))

        // Build up state here: scroll, select, type, start playback.
        let before = summary.label
        let startSize = sizeClass.label

        app.buttons["continuity.flip"].tap()
        let flipped = startSize == "compact" ? "regular" : "compact"
        XCTAssertTrue(sizeClass.wait(for: \.label, toEqual: flipped, timeout: 5))
        XCTAssertEqual(summary.label, before, "state changed on a size-class flip")

        app.buttons["continuity.flip"].tap()
        XCTAssertTrue(sizeClass.wait(for: \.label, toEqual: startSize, timeout: 5))
        XCTAssertEqual(summary.label, before, "state changed on the flip back")

        let windowSize = app.staticTexts["continuity.windowSize"]
        let sizeBefore = windowSize.label
        XCUIDevice.shared.orientation = .landscapeLeft
        let resized = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", sizeBefore),
                                                object: windowSize)
        XCTAssertEqual(XCTWaiter().wait(for: [resized], timeout: 5), .completed, "rotation did not resize the app")
        XCTAssertEqual(summary.label, before, "state changed on rotation")
        XCUIDevice.shared.orientation = .portrait
    }

    /// Real fold. Run with TEST_RUNNER_DUO_MANUAL_FOLD=1 and press the Device Hub buttons when asked.
    @MainActor
    func testStateSurvivesRealFold() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DUO_MANUAL_FOLD"] == "1",
                          "Manual test: needs someone to press Closed and Open in Device Hub.")
        let app = launch()
        let summary = app.staticTexts["continuity.summary"]
        let sizeClass = app.staticTexts["continuity.sizeClass"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        let before = summary.label

        XCTContext.runActivity(named: "Press Closed in Device Hub") { _ in
            XCTAssertTrue(sizeClass.wait(for: \.label, toEqual: "compact", timeout: 60))
            XCTAssertEqual(summary.label, before, "state changed on close")
        }
        XCTContext.runActivity(named: "Press Open in Device Hub") { _ in
            XCTAssertTrue(sizeClass.wait(for: \.label, toEqual: "regular", timeout: 60))
            XCTAssertEqual(summary.label, before, "state changed on open")
        }
    }
}
```

Run them:

```bash
# Automatic test
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcodebuild test \
  -scheme YourApp -destination 'platform=iOS Simulator,name=iPhone Duo,OS=27.1' \
  -only-testing:YourAppUITests/ContinuityUITests/testStateSurvivesSizeClassFlipAndRotation

# Manual fold test: keep Device Hub visible and press the buttons when the test waits
TEST_RUNNER_DUO_MANUAL_FOLD=1 DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcodebuild test \
  -scheme YourApp -destination 'platform=iOS Simulator,name=iPhone Duo,OS=27.1' \
  -only-testing:YourAppUITests/ContinuityUITests/testStateSurvivesRealFold
```

- `xcodebuild` passes any `TEST_RUNNER_` variable to the test runner with the prefix removed (`man xcodebuild`, Xcode 27.1).
- [wait(for:toEqual:timeout:)](https://developer.apple.com/documentation/xcuiautomation/xcuielement/wait(for:toequal:timeout:)) polls a key path until it matches. [XCTSkipUnless](https://developer.apple.com/documentation/xctest/xctskipunless(_:_:file:line:)) keeps the manual test out of normal runs.
- The summary should hold only what must not change. Leave the size class out of it.
- *Unverified:* we typechecked these tests against the Xcode 27.1 SDK but have not yet run them on the simulator. In particular, check that `XCUIDevice.shared.orientation` resizes your app on the open inner display, which doesn't honour supported orientations, and that the test finds the labels at 2% opacity (raise it if not).
- `duo-testing` has general tips for UI tests on the Duo simulator.

## Quick checks without a test target

- Print the state summary from `onChange(of: sizeClass)` and watch the console while you press the Device Hub buttons.
- Add `let _ = Self._printChanges()` to a view body while debugging. It prints why the body ran. `@identity` in that line means the view got a new identity. *Measured:* after a flip, a view inside an `if`/`else` printed `@self, @identity, __count changed.`, and the same view inside `AnyLayout` printed `@self changed.` The underscore marks it as not public API: use it in debug builds only, and don't parse its output.
