---
id: duo-accessibility/large-text-closed
skill: duo-accessibility
also: duo-design-system
title: The inbox at the largest text sizes
readme: no
fixture: Inbox
project: Inbox.xcodeproj
scheme: Inbox
build: yes
lint: yes
checklist: R3 R10
timeout: 1800
status: ready
---

# The inbox at the largest text sizes

The closed outer display is the narrowest window an iPhone Duo app gets, and text size settings follow the person to it. Apple asks apps to show as much text at the largest accessibility size as at the largest standard size, and to stack items that crowd instead of truncating them ([HIG, Typography](https://developer.apple.com/design/human-interface-guidelines/typography#Supporting-Dynamic-Type)).

## Prompt

```text prompt
People who use the largest text sizes say the inbox is hard to read on the closed iPhone Duo: text is cut off and rows overlap. Make the inbox and the message screen work at every text size, closed and open, without hiding any information. Keep the accessibility identifiers and the InboxUITests target.
```

## Starting point

Fixture [`Inbox`](../../fixtures/Inbox): a mail inbox. Open, a custom list and message pane sit side by side; closed, the list pushes the message. iOS 17 target, Swift 5, with a UI test target, `InboxUITests`. duo-lint finds nothing.

- Every text uses a fixed point size (`.font(.system(size: 16))`), so none of it follows the text size setting.
- Each row has a fixed height of 76 pt and the preview line is cut to one line with `lineLimit(1)`.
- The message header puts the sender and date in a 40 pt high box.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check no-fixed-row-heights
# Rows and text boxes don't get a fixed height (a 1 pt divider is fine).
no_src '\.frame\(height: *(4[0-9]|[5-9][0-9]|[1-9][0-9]{2})(\.[0-9]+)?\)'
```

```sh check oracle-largest-text
# A hidden UI test, written into the UI test folder after the run. It launches the
# app at the largest accessibility text size (AX5) and runs Xcode's accessibility
# audit for text that doesn't scale and text that is clipped, on the inbox and
# again after opening the first message. It runs in whatever pose the simulator is
# in; closed is the hard case.
[ -d InboxUITests ] || { echo "the InboxUITests folder is gone"; exit 1; }
cat > InboxUITests/LargeTextOracleTests.swift <<'SWIFT'
import XCTest

final class LargeTextOracleTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLargestTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let row = app.descendants(matching: .any).matching(identifier: "inbox.row.1").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20), "inbox.row.1 is missing")
        try audit(app, screen: "the inbox")
        row.tap()
        let subject = app.descendants(matching: .any).matching(identifier: "message.subject").firstMatch
        XCTAssertTrue(subject.waitForExistence(timeout: 10), "message.subject is missing after opening the first message")
        try audit(app, screen: "the message")
    }

    private func audit(_ app: XCUIApplication, screen: String) throws {
        var problems: [String] = []
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped]) { issue in
            problems.append("\(issue.compactDescription): \(issue.element?.label ?? "an element")")
            return true
        }
        XCTAssertTrue(problems.isEmpty, "\(screen) at AX5: \(problems.joined(separator: "; "))")
    }
}
SWIFT
xcb_test -only-testing:InboxUITests/LargeTextOracleTests
```

## Checklist

The reviewer sets the text size to AX5 (`xcrun simctl ui <UDID> content_size accessibility-extra-extra-extra-large`, and back to `large` afterwards):

- **R3**: closed, upright and sideways, nothing is clipped, overlaps or runs off the window; rows grow and stack. Open, lines don't run the full width of the inner display.
- **R10**: closed, every piece of a row (sender, date, subject, preview, unread mark) is still there, and the message screen shows the whole message and both buttons.
