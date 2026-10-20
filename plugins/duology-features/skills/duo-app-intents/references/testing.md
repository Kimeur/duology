# Testing intents in each pose

AppIntentsTesting (Xcode 27) runs your intents, queries and view annotations from a UI test bundle, in the real app, without Siri ([App Intents Testing](https://developer.apple.com/documentation/appintentstesting), [WWDC26 session 295](https://developer.apple.com/videos/play/wwdc2026/295/)). *Measured:* it works on the iPhone Duo simulator, closed and open. This page has the test, how to run it per pose, and what tripped us up.

## The test

```swift
import XCTest
import AppIntentsTesting

/// Runs the app's intents on the iPhone Duo simulator, from a UI test bundle.
/// A test can't fold the phone: set the pose in Device Hub (or with duo-pose) before each run.
final class NoteIntentTests: XCTestCase {
    let definitions = IntentDefinitions(bundleIdentifier: "com.example.notes")

    @MainActor
    func testOpenNoteShowsItInThisPose() async throws {
        let app = XCUIApplication()
        app.launch()

        try await definitions.intents["OpenNoteIntent"].makeIntent(target: "Trip").run()

        // Closed: the split view collapses to the note. Open: the list stays beside it.
        XCTAssertTrue(app.staticTexts["Trip"].waitForExistence(timeout: 5))
        let annotations = try await definitions.entities["NoteEntity"].viewAnnotations()
        let titles = annotations.compactMap { annotation -> String? in try? annotation.entity.title }
        XCTAssertTrue(titles.contains("Trip"), "On screen for Siri: \(titles)")
    }

    @MainActor
    func testSummaryRunsWithoutOpeningTheApp() async throws {
        let app = XCUIApplication()
        app.launch()
        XCUIApplication(bundleIdentifier: "com.apple.Preferences").activate()   // put the app behind
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))

        let result = try await definitions.intents["ReadNoteSummaryIntent"].makeIntent(note: "Trip").run()
        let summary: String = try result.value
        XCTAssertFalse(summary.isEmpty)
        XCTAssertNotEqual(app.state, .runningForeground)                          // still behind
    }
}
```

- The test target doesn't import your app. It finds intents and entities by type name (`"OpenNoteIntent"`, `"NoteEntity"`) and parameters by name, so typos fail at run time, not at build time.
- Pass an entity parameter as a string. Apple says `makeIntent` resolves plain values for you ([guide](https://developer.apple.com/documentation/appintentstesting/testing-your-app-intents-code)); in our runs, `"Trip"` reached the Trip note through the `EntityStringQuery`. Give every entity a string query so tests and Siri can find items by name.
- Read entity properties by name (`annotation.entity.title`). Only `@Property` properties are readable; a plain `let` was not (*measured*: the read threw until we added `@Property`).
- Apple says the UI test target must use the same code signing team as the app (same guide). On the simulator, our app and test bundle, both signed to run locally with no team, worked.

## Run it closed and open

```bash
# Set the pose first. duo-pose refuses while UI tests run, so never overlap them.
duo-pose set closed
xcodebuild test -project Notes.xcodeproj -scheme Notes \
  -destination "id=<iPhone Duo UDID>" \
  -parallel-testing-enabled NO -collect-test-diagnostics never
duo-pose set open
xcodebuild test -project Notes.xcodeproj -scheme Notes \
  -destination "id=<iPhone Duo UDID>" \
  -parallel-testing-enabled NO -collect-test-diagnostics never
```

- `duo-pose` comes with `duo-pose-matrix`; it needs the user's Accessibility permission. Without it, ask the user to press Closed or Open in Device Hub before each run.
- Don't let tests clone the simulator (`-parallel-testing-enabled NO`); a Duo clone takes gigabytes and minutes to boot.
- Name the expected layout in the test (for example a launch argument `-expectedPose closed`) if one test file should assert different things per pose.

## What tripped us up

- **Pressing Home didn't background the app** on the Duo simulator: after `XCUIDevice.shared.press(.home)`, the app still reported `.runningForeground` (*measured*, closed). Activating Settings worked.
- **Annotations right after launch were not stable:** one run reported the three list rows, another reported none. Wait for an element first.
- **Other apps on a shared simulator** can take the front while your test runs and change `app.state`. On a shared machine, log your app's scene phase as well and trust that.
- **Foundation Models in the simulator:** an intent that calls the on-device model got an error on our Mac, although availability said yes (`duo-intelligence` evidence). Test the intent's fallback path, and test real answers on a device.
- **Siri itself** is not part of this. *Unverified:* Siri and Apple Intelligence requests on the Duo simulator.
