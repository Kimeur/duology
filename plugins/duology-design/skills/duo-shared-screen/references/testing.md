# Testing a shared screen

UI tests that cover both seats, launch switches, and the rules checked on the Mac. The app-side types come from [SKILL.md](../SKILL.md).

*Measured* means we ran it on the iPhone Duo simulator (Xcode 27.1, iOS 27.1). *Unverified* means we could not confirm it.

## Identifiers

Start every identifier with the seat, then the thing, then its id:

| Identifier | Element |
|---|---|
| `first`, `second` | the half itself (`SeatHalf` sets it) |
| `first.piece` | the first seat's piece |
| `second.piece.3` | the second seat's piece 3 |
| `first.score` | the first seat's score |
| `second.leave`, `second.leave.confirm` | the Leave button, before and after the first tap |

One test then covers both seats with a loop over `["first", "second"]`.

## Launch switches

Let tests open the shared screen directly, pick the seating and the turn mode. Honour the switches only in debug builds.

```swift
import Foundation

/// Launch switches for UI tests. A release build ignores them.
enum TestSwitches {
    static let arguments = ProcessInfo.processInfo.arguments

    #if DEBUG
    static let isUITesting = arguments.contains("-uiTesting")
    #else
    static let isUITesting = false
    #endif

    /// `-seating faceToFace` or `-seating sameWay`.
    static var seating: Facing? {
        guard isUITesting, let i = arguments.firstIndex(of: "-seating"), i + 1 < arguments.count else { return nil }
        return Facing(rawValue: arguments[i + 1])
    }

    static var takesTurns: Bool { isUITesting && arguments.contains("-takeTurns") }

    /// Call once at launch, before any view reads `@AppStorage("seating")`.
    /// UI tests start side by side unless they pass `-seating`.
    static func applyToDefaults() {
        guard isUITesting else { return }
        UserDefaults.standard.set((seating ?? .sameWay).rawValue, forKey: "seating")
    }
}
```

Read `takesTurns` where you create the `SeatGate`.

The simulator clone did not rotate when a test set `XCUIDevice.shared.orientation` (*measured*: the device reported landscape, the app window stayed 466 × 678 pt). To test the side-by-side split from a script, add a test-only switch that gives the split a wide frame, and check real rotation by hand in Device Hub.

## Helpers

```swift
import XCTest

extension XCUIApplication {
    func element(_ id: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: id).firstMatch
    }
}

/// Converts a spot in the owner's layout (0...1 on each axis, from the owner's
/// top-left) to the screen offset that XCUITest wants for that half.
func screenOffset(_ owner: CGVector, quarterTurns: Int) -> CGVector {
    switch (quarterTurns % 4 + 4) % 4 {
    case 1: CGVector(dx: 1 - owner.dy, dy: owner.dx)
    case 2: CGVector(dx: 1 - owner.dx, dy: 1 - owner.dy)
    case 3: CGVector(dx: owner.dy, dy: 1 - owner.dx)
    default: owner
    }
}

extension XCUIElement {
    /// Drags from this element's centre to an offset in `target`.
    /// A press before the drag reaches SwiftUI's DragGesture.
    func drag(to target: XCUIElement, at offset: CGVector) {
        coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.3, thenDragTo: target.coordinate(withNormalizedOffset: offset))
    }
}
```

- `coordinate(withNormalizedOffset:)` works in screen space, from the element's frame ([doc](https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:))). In a turned half, `screenOffset` turns an owner's spot into that.
- *Measured:* `screenOffset` matches what the probe saw. Upside down, the screen offset (0.10, 0.15) arrived at the owner's (0.90, 0.85). A quarter turn each way gave the owner's (0.10, 0.85) and (0.90, 0.15) for screen (0.15, 0.10).
- *Measured:* `press(forDuration: 0.3, thenDragTo:)` reached `DragGesture(minimumDistance: 6)` in every run ([doc](https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/press(forduration:thendragto:))).

## A test for both seats and both seatings

```swift
import XCTest

@MainActor
final class SeatingUITests: XCTestCase {
    func testTapsWorkInEverySeatAndSeating() {
        for seating in ["sameWay", "faceToFace"] {
            let app = XCUIApplication()
            app.launchArguments = ["-uiTesting", "-seating", seating]
            app.launch()
            for seat in ["first", "second"] {
                let piece = app.element("\(seat).piece")
                XCTAssertTrue(piece.waitForExistence(timeout: 5), "\(seating) \(seat)")
                let before = Int(app.element("\(seat).score").label) ?? 0
                piece.tap()
                XCTAssertEqual(Int(app.element("\(seat).score").label), before + 1, "\(seating) \(seat): tap")
            }
            app.terminate()
        }
    }

    func testOnlyOneSeatCanLeaveAndItAsksFirst() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertFalse(app.element("first.leave").exists, "Leave lives on one seat")
        app.element("second.leave").tap()
        XCTAssertTrue(app.element("second.leave.confirm").waitForExistence(timeout: 2), "first tap only arms")
    }
}
```

## Where the tests run

- *Measured:* `xcodebuild test` ran our UI tests on "Clone 1 of iPhone Duo", not on the booted simulator itself. The clone started closed, on the outer display. So a scripted run checks the closed phone unless you set things up otherwise.
- `simctl` in Xcode 27.1 has no pose command (*measured* for `reference/device-facts.md`). Change poses by hand in Device Hub: Closed, Partially Open, Open ([doc](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)).
- Device Hub can't send two touches at once ([Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)). Two people playing together is a device test.
- Haptics don't play on the simulator. Device test.

```bash
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer \
xcodebuild test -project MyApp.xcodeproj -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone Duo'
```

## Rules on the Mac

`Seat`, `Facing` and `SeatGate` are plain Swift, so you can check them on the Mac in a second, without a simulator. Put them in their own file (`Seats.swift`, from SKILL.md section 1), then add this `main.swift` next to it:

```swift
// xcrun swiftc Seats.swift main.swift -o seats-check && ./seats-check
import Foundation

func failedChecks() -> [String] {
    var failed: [String] = []
    func check(_ ok: Bool, _ what: String) { if !ok { failed.append(what) } }

    var gate = SeatGate()
    gate.mode = .takeTurns
    check(gate.canAct(.first) && !gate.canAct(.second), "first goes first")
    gate.finishTurn(of: .second)
    check(gate.current == .first, "a seat can't end the other seat's turn")
    gate.finishTurn(of: .first)
    check(gate.canAct(.second) && !gate.canAct(.first), "then second")
    gate.isPaused = true
    check(!gate.canAct(.first) && !gate.canAct(.second), "pause blocks both")
    check(SeatGate().canAct(.first) && SeatGate().canAct(.second), "together: both act")

    for seat in Seat.allCases {
        check(Facing.sameWay.quarterTurns(for: seat, sideBySide: true) == 0, "same way never turns")
    }
    check(Facing.faceToFace.quarterTurns(for: .first, sideBySide: false) == 2, "top half upside down")
    check(Facing.faceToFace.quarterTurns(for: .second, sideBySide: false) == 0, "bottom half upright")
    let sideways = Seat.allCases.map { Facing.faceToFace.quarterTurns(for: $0, sideBySide: true) }
    check(Set(sideways) == [1, 3], "side by side: opposite quarter turns")
    return failed
}

let failed = failedChecks()
failed.forEach { print("FAIL", $0) }
print(failed.isEmpty ? "ALL PASS" : "\(failed.count) FAILED")
exit(failed.isEmpty ? 0 : 1)
```

*Measured:* it prints `ALL PASS` with Swift 5 and Swift 6 language modes. Add a check for every rule your app adds: who may act, when a round ends, who wins a tie.
