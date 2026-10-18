# Testing accessibility on the iPhone Duo simulator

Three tools, used in every pose: the simulator's settings, Accessibility Inspector, and UI tests. Set up the UI test target as `duo-testing` describes.

## Settings

| Setting | Turn on | Turn off |
|---|---|---|
| Text size | `xcrun simctl ui <UDID> content_size accessibility-extra-extra-extra-large` | `… content_size large` |
| Increase Contrast | `xcrun simctl ui <UDID> increase_contrast enabled` | `… increase_contrast disabled` |
| Dark appearance | `xcrun simctl ui <UDID> appearance dark` | `… appearance light` |
| VoiceOver | `xcrun devicectl device settings voiceover -d <UDID> --enable` | `… --disable` |
| Reduce Motion, Reduce Transparency, Bold Text, Button Shapes, Differentiate Without Color, Full Keyboard Access | Accessibility Inspector, Settings pane, or the simulator's Settings app | the same place |

- Run `xcrun simctl ui <UDID> content_size` (no value) to read the current size, and `xcrun devicectl device info voiceover -d <UDID>` to read VoiceOver's state.
- These settings belong to the whole simulator. On a shared simulator, every app and every other test sees them. Put each one back when you finish.
- For one run, prefer a launch argument for the text size: `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` (*measured*: the app got `.accessibility5`).

## Accessibility Inspector

Open it from Xcode > Open Developer Tool > Accessibility Inspector ([doc](https://developer.apple.com/documentation/accessibility/accessibility-inspector)). In each pose (Closed, Open, Partially Open, and Split View on the inner display):

1. **Target.** Pick the simulator in the target menu, then your app ([Inspecting screens](https://developer.apple.com/documentation/accessibility/inspecting-the-accessibility-of-screens)).
2. **Order.** Select the first element and press the navigation play button. The inspector walks the screen in the order VoiceOver uses and can speak each element. Listen for panes that interleave.
3. **Elements.** Turn on inspection (Option-Space) and tap the elements you placed yourself: their frame should hug the control, not fill a pane.
4. **Audit.** Run an audit in the Audits pane. Each issue has an explanation, a highlight, a screenshot and a fix suggestion. Save the report as HTML for a design review ([Audits](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app)).
5. **Settings.** Toggle Reduce Motion, Increase Contrast, Bold Text and the others in the Settings pane while the app runs ([doc](https://developer.apple.com/documentation/accessibility/testing-system-accessibility-features-in-your-app)). The colour contrast calculator is under Window (Option-Command-C).

An audit with no issues does not prove the app is accessible. Apple also asks for a run with VoiceOver and the other assistive technologies ([Audits](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app)).

## Audits

`performAccessibilityAudit(for:_:)` runs the inspector's audit from a UI test and fails the test for each issue it finds. Return `true` from the handler to ignore an issue you have checked.

```swift
import XCTest

@MainActor
final class AuditTests: XCTestCase {
    func testAuditAtDefaultSize() throws {
        let app = XCUIApplication()
        app.launch()
        try app.performAccessibilityAudit()
    }

    func testAuditAtLargestText() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .hitRegion, .sufficientElementDescription]) { issue in
            // Ignore only issues a person has checked. Here: none.
            print("AUDIT", issue.auditType, issue.compactDescription, issue.element?.identifier ?? "")
            return false
        }
    }
}
```

*Measured* on the closed display:

| Screen | Issues the audit reported |
|---|---|
| Icon with a tap gesture, 20 × 20 pt | "Hit area is too small" |
| Plain icon button, 16 × 16 pt | "Hit area is too small" |
| Icon-only `Button` with `.frame(minWidth: 44, minHeight: 44)` on the button, outside its label | "Hit area is too small": put the frame and `contentShape` inside the label, as `duo-ergonomics` does |
| `Color(white: 0.85)` text on white | "Contrast failed" |
| `.secondary` text, a tinted button title | "Contrast nearly passed" |
| `.font(.system(size: 13))` | "Dynamic Type font sizes are unsupported" |
| Row with `lineLimit(1)` and `frame(height: 30)` | "Text clipped", twice, at Large and at AX5 |
| The same row reflowed with `AnyLayout` | none, at Large and at AX5 |

The audit named the 20 pt icon "Trash" from its symbol name. That label came for free; for anything else, write one.

## A VoiceOver walk

Xcode 27 adds `XCUIDevice.shared.voiceOverService` (iOS 27): turn VoiceOver on, move through elements, and read what it says (iOS 27.1 platform headers: `XCUIVoiceOverService.h`).

```swift
import XCTest

@MainActor
final class ReadingOrderTests: XCTestCase {
    /// Moves VoiceOver forward `steps` times and returns what it spoke.
    @available(iOS 27.0, *)
    private func walk(_ steps: Int) throws -> [String] {
        let voiceOver = XCUIDevice.shared.voiceOverService
        addTeardownBlock { @MainActor in
            if voiceOver.isEnabled { try? voiceOver.disable() }   // never leave it on
        }
        try voiceOver.enable()
        var spoken = [try voiceOver.currentSpeech().utterance]
        for _ in 0..<steps { spoken.append(try voiceOver.moveForward().utterance) }
        try voiceOver.disable()
        return spoken
    }

    func testListPaneIsReadBeforeDetailPane() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("needs the iOS 27 VoiceOver service") }
        let app = XCUIApplication()
        app.launch()
        let spoken = try walk(12)
        let lastRow = spoken.lastIndex { $0.hasPrefix("Row") } ?? -1
        let detail = spoken.firstIndex { $0.contains("Message pane") } ?? spoken.count
        XCTAssertLessThan(lastRow, detail, spoken.joined(separator: " | "))
    }
}
```

What we learned running walks like this (*measured*):

- Each step took about 2 s. A 14-step walk made a test last about 35 s.
- The first utterance can include the app name ("A11yProbe Inbox, Heading") or, on the open phone, the orientation ("Port on left"). Don't assert on it.
- At the end of the screen, `moveForward()` keeps returning the last element. Stop on a repeat.
- `moveIn()` and `moveOut()` exist for containers (iOS and macOS only).
- The order of `app.staticTexts` is not VoiceOver's order. On an open `NavigationSplitView`, XCUI listed detail rows before sidebar rows; VoiceOver read the sidebar first.
- If the test process dies before teardown, VoiceOver stays on in the simulator. Turn it off with `xcrun devicectl device settings voiceover -d <UDID> --disable`.

## Focus after a real fold

No API changes the pose from a test ([`duo-testing`](https://github.com/Kimeur/duology/blob/main/plugins/duology-ship/skills/duo-testing/SKILL.md)). The test waits while the pose changes, by hand in Device Hub or with a Mac script (see `duo-setup`). The app shows a marker whose label says "wide" or "narrow".

```swift
import XCTest

@MainActor
final class FoldFocusTests: XCTestCase {
    func testVoiceOverKeepsItsPlaceWhenClosed() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("needs the iOS 27 VoiceOver service") }
        let app = XCUIApplication()
        app.launch()
        let marker = app.staticTexts["layout.width"]
        XCTAssertTrue(marker.waitForExistence(timeout: 15))
        try XCTSkipUnless(marker.label == "wide", "start with the phone open")

        let voiceOver = XCUIDevice.shared.voiceOverService
        addTeardownBlock { @MainActor in
            if voiceOver.isEnabled { try? voiceOver.disable() }
        }
        try voiceOver.enable()
        for _ in 0..<10 {
            if try voiceOver.moveForward().utterance.contains("Row 2") { break }
        }
        print("READY: press Closed in Device Hub")

        XCTAssertTrue(marker.wait(for: \.label, toEqual: "narrow", timeout: 120))
        sleep(4)                                            // let the layout and the focus move settle
        let landed = try voiceOver.currentSpeech().utterance
        XCTAssertTrue(landed.contains("Lunch on Friday"), "VoiceOver landed on: \(landed)")
        try voiceOver.disable()
    }
}
```

- Run it alone (`-only-testing:`), watch the log for `READY`, then press the pose.
- Check that no other test runs on a shared simulator before you change its pose, and put the pose back afterwards.
- The marker is debug-only UI. Gate it as `duo-testing` gates `testMarker`.

## Keyboard in UI tests

- `app.typeKey("n", modifierFlags: .command)` sends a shortcut; `typeText` types into the focused field. *Measured* closed: `typeKey("a", modifierFlags: [])` into a focused field typed nothing, `typeText("hello")` worked.
- A shortcut press was sometimes ignored, once before the first tap and once right after one. Wait for the result after each press.
- Don't assert that Tab moves focus: it changed between runs (*measured*).
