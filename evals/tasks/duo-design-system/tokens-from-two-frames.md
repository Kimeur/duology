---
id: duo-design-system/tokens-from-two-frames
skill: duo-design-system
also: duo-accessibility, duo-patterns
title: A design system from a closed and an open frame
readme: no
fixture: Trips
project: Trips.xcodeproj
scheme: Trips
build: yes
lint: yes
checklist: R3 R5 R13
timeout: 2400
status: ready
---

# A design system from a closed and an open frame

Designers often hand over one frame for the closed phone and one for the open phone, and the easy translation is "if the screen is wide, use the big numbers". Apple asks for the opposite: size classes instead of screen sizes, the same text sizes on both displays with Dynamic Type, even column counts where a fold crosses a grid, corners that follow the display instead of a hard-coded radius, and 44 pt targets ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=230), [talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=456), [talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=258), [HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Vision)).

## Prompt

```text prompt
Design/frames.md describes our designer's two frames for the Trips screen, one for the closed phone and one for the open phone. Turn them into a small design system for this app (spacing, type, grid, corners, colours and touch targets) in its own Swift file, and make the Trips screen use it. The screen must adapt closed, open and partly folded without checking which display or device it runs on, and it must work with large text, dark mode and Increase Contrast. Where the frames conflict with those needs, follow the needs and tell me what you changed. Keep the accessibility identifiers and the TripsUITests target.
```

## Starting point

Fixture [`Trips`](../../fixtures/Trips): a grid of trip cards with a heart button on each (`trip.favorite.<id>`) and a "Plan a trip" button (`trips.plan`). iOS 17 target, Swift 5, with a UI test target, `TripsUITests`. `Design/frames.md` holds the two frames. The code follows them literally:

- `isOpen` comes from `UIScreen.main.bounds.width > 600` (duo-lint DUO001) and picks margins, card sizes, text sizes and the column count (1 closed, 3 open).
- Every text has a fixed point size, larger when open.
- The dates are `Color(white: 0.7)` on a white card, about 2.1:1.
- The heart buttons are 30 pt circles.
- Cards have a fixed 55 pt corner radius "like the phone's screen".

What the frames get wrong, by rubric rule: three columns open (R5), sizes scaled from the closed frame (R3), 30 pt hearts (R13), grey dates that fail contrast, and a display-shaped radius.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing (so no `UIScreen.main`, idiom or orientation).

```sh check tokens-in-their-own-file
# The prompt asks for the design system in its own Swift file: at least one Swift
# file in the app that the fixture doesn't have (UI test files don't count).
new=""
for f in $(swift_files); do
  case "$f" in *UITests/*) continue ;; esac
  [ -f "$EVALS/fixtures/Trips/${f#./}" ] || new="$new ${f#./}"
done
[ -n "$new" ] || { echo "no new Swift file in the app"; exit 1; }
echo "new Swift files:$new"
```

```sh check one-type-scale
# No fixed text sizes: a literal or per-display size ignores Dynamic Type and gives
# the two displays different type. Text styles, Font.custom(_:size:relativeTo:) or
# sizes from @ScaledMetric pass.
no_src '\.system\(size: *([0-9]|[A-Za-z_.]+ *\?)'
no_src 'fixedSize:'
```

```sh check no-display-radius
# No corner radius copied from a display (40 pt or more).
no_src 'cornerRadius: *[4-9][0-9]'
```

```sh check oracle-contrast-type-and-targets
# A hidden UI test, written into the UI test folder after the run, in whatever pose
# the simulator is in. At the default text size: no contrast failure and no text that
# ignores Dynamic Type (Xcode's accessibility audit), and the first heart button is at
# least 44 x 44 pt. At AX5: no clipped text. The audit also reports "contrast nearly
# passed" for the system's secondary label colour; only failures count here.
[ -d TripsUITests ] || { echo "the TripsUITests folder is gone"; exit 1; }
cat > TripsUITests/TokensOracleTests.swift <<'SWIFT'
import XCTest

final class TokensOracleTests: XCTestCase {
    @MainActor
    func testDefaultTextSize() throws {
        let app = XCUIApplication()
        app.launch()
        let heart = app.descendants(matching: .any).matching(identifier: "trip.favorite.1").firstMatch
        XCTAssertTrue(heart.waitForExistence(timeout: 20), "trip.favorite.1 is missing")
        var problems: [String] = []
        // 0.5 pt of slack: a 44 pt frame can come back as 43.99999.
        if heart.frame.width < 43.5 || heart.frame.height < 43.5 {
            problems.append("the heart button is \(Int(heart.frame.width)) x \(Int(heart.frame.height)) pt")
        }
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType]) { issue in
            if issue.auditType == .contrast && !issue.compactDescription.lowercased().contains("failed") {
                return true
            }
            problems.append("\(issue.compactDescription): \(issue.element?.label ?? "an element")")
            return true
        }
        XCTAssertTrue(problems.isEmpty, problems.joined(separator: "; "))
    }

    @MainActor
    func testLargestTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "trip.favorite.1").firstMatch
            .waitForExistence(timeout: 20), "trip.favorite.1 is missing")
        var problems: [String] = []
        try app.performAccessibilityAudit(for: [.textClipped]) { issue in
            problems.append("\(issue.compactDescription): \(issue.element?.label ?? "an element")")
            return true
        }
        XCTAssertTrue(problems.isEmpty, "at AX5: " + problems.joined(separator: "; "))
    }
}
SWIFT
xcb_test -only-testing:TripsUITests/TokensOracleTests
```

## Checklist

- **R5**: Open, held wide, flat and Partially Open: the grid has an even number of columns and the fold runs through a gap, never through a card.
- **R3**: closed and open, margins and card sizes come from the window (or the system's margins), not from a screen width; nothing is scaled up from the closed frame.
- **R13**: every heart button and the "Plan a trip" button are at least 44 pt, closed and open, also at AX5.

Also note, outside the rule verdicts: whether the agent's final message says which parts of the frames it changed (three columns, fixed sizes, the grey, the 30 pt hearts, the radius), and whether card corners follow the display (`ConcentricRectangle`) or use a modest fixed radius.
