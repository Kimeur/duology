---
id: duo-ergonomics/thumb-reach
skill: duo-ergonomics
also: duo-navigation, duo-layout
title: Controls within thumb reach, closed and open
readme: no
fixture: Trail
project: Trail.xcodeproj
scheme: Trail
build: yes
lint: yes
checklist: R4 R6 R13
timeout: 1800
status: ready
---

# Controls within thumb reach, closed and open

Apple moves bars to the side edge of iPhone Duo partly so thumbs reach them, and calls the middle and bottom of an iPhone display the easy zone ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=70), [HIG, Designing for iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios#Best-practices)). Open, the display is about twice as wide, so a control in the top centre is far from both hands. Tap targets need at least 44 × 44 pt ([HIG, Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons#Best-practices)).

## Prompt

```text prompt
People say this walk-tracking screen is awkward on iPhone Duo. Holding the phone closed in one hand, or open in both hands, they can't reach the Record, Lap and Locate buttons without changing their grip, and the buttons are small. Move the controls to where thumbs reach them, closed and open, and keep them off the fold when the phone is half folded. Keep all three buttons on screen with their accessibility identifiers (track.record, track.lap, track.locate), and keep the TrailUITests target.
```

## Starting point

Fixture [`Trail`](../../fixtures/Trail): a drawn map, a stats panel at the bottom and three buttons in a capsule pinned to the top centre of the window with `.overlay(alignment: .top)`. Each button is a 30 pt circle. iOS 17 target, Swift 5, with a UI test target, `TrailUITests`. duo-lint finds nothing.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check buttons-kept
for id in track.record track.lap track.locate; do
  has_src "\"$id\""
done
```

```sh check off-the-fold
# Some way of keeping the buttons off the fold: system bars (which move off it on
# their own), the fold's reserved region, an arrangement, or a corner anchor that
# keeps them against a side edge.
has_src '\.toolbar|ToolbarItem|reservedRegions\(kind: *\.division|ArrangementView|bottomLeading|bottomTrailing|toolbarVerticalEdge|verticalBarEdge'
```

```sh check oracle-reach
# A hidden UI test, written into the UI test folder after the run. In whatever pose
# the simulator is in (closed, unless someone changed it), each button must exist,
# be tappable, measure at least 44 x 44 pt, and stay out of the top centre of the
# window: the top 40 percent of its height inside the middle half of its width.
# Buttons in a vertical side bar pass: Apple places that bar for the thumb.
[ -d TrailUITests ] || { echo "the TrailUITests folder is gone"; exit 1; }
cat > TrailUITests/ReachOracleTests.swift <<'SWIFT'
import XCTest

final class ReachOracleTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testButtonsAreInReach() throws {
        let app = XCUIApplication()
        app.launch()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 20), "the app has no window")
        let bounds = window.frame
        for id in ["track.record", "track.lap", "track.locate"] {
            let button = app.descendants(matching: .any).matching(identifier: id).firstMatch
            guard button.waitForExistence(timeout: 10) else {
                XCTFail("\(id) is missing")
                continue
            }
            XCTAssertTrue(button.isHittable, "\(id) can't be tapped")
            let frame = button.frame
            // 0.5 pt of slack: a 44 pt frame can come back as 43.99999.
            XCTAssertGreaterThanOrEqual(frame.width, 43.5, "\(id) is \(frame.width) pt wide")
            XCTAssertGreaterThanOrEqual(frame.height, 43.5, "\(id) is \(frame.height) pt tall")
            let inTopCentre = frame.midY < bounds.minY + bounds.height * 0.4
                && frame.midX > bounds.minX + bounds.width * 0.25
                && frame.midX < bounds.maxX - bounds.width * 0.25
            XCTAssertFalse(inTopCentre, "\(id) sits in the top centre of a \(bounds.size) window, at \(frame)")
        }
    }
}
SWIFT
xcb_test -only-testing:TrailUITests/ReachOracleTests
```

## Checklist

- **R13**: closed and open, each button is at least 44 pt and has room around it.
- **R6**: closed upright, the buttons sit in the system's vertical bar or near its edge, in its lower part; open and held wide, near a side edge, not in the top centre. Icon-only buttons still have titles.
- **R4**: Partially Open, held wide and held tall: no button touches the fold.
