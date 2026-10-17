# Logic tests on the Mac

The fastest tests for an iPhone Duo app never touch the Duo. Game rules, scoring, layout maths, parsers and state machines are plain Swift. Test them on the Mac in seconds, and save the simulator for flows that need the real app.

Everything on this page ran on 16 October 2026 with Xcode 27.1 (27A9275), Swift 6.4, on macOS 27.0.1.

## What belongs in the logic layer

| Put it in plain Swift | Keep it in the UI layer |
|---|---|
| Rules: what a move does, who won, when a round ends | Gestures, hit testing, animation |
| Maths: column counts, how to split a list, scores | `GeometryReader`, size classes, reserved regions |
| Parsing and formatting | Fonts, colours, SF Symbols |
| A timer's logic, given a clock you pass in | `Timer`, `TimelineView` |
| Persistence formats (`Codable` structs) | `@AppStorage`, `@SceneStorage` |

Rules of thumb:

- `import Foundation` only. No SwiftUI, UIKit, AVFoundation or StoreKit in these files.
- Pass time in (`Date`, a duration) instead of reading the clock inside the logic. Tests can then use fixed dates.
- Pass randomness in (a seeded generator) so tests are repeatable.
- Mark each type `nonisolated` and `Sendable` (next section).

## Why `nonisolated`

The Xcode 27.1 app template sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` on the app target (checked in Xcode 27.1's `App Base` project template). In that target, a plain `struct` is main-actor isolated by default. The same file compiled by `swiftc` for a test script, or inside a Swift package, is not. Marking the type `nonisolated` makes both builds see the same thing.

```swift
import Foundation

/// Picks a column count for a grid. When more than one column fits, the count is even,
/// so a grid that spans the inner display puts a gap, not a column, on the fold.
nonisolated struct GridPlan: Equatable, Sendable {
    var columns: Int
    var columnWidth: Double

    static func make(width: Double, minColumnWidth: Double, spacing: Double = 8) -> GridPlan {
        guard width > 0, minColumnWidth > 0 else { return GridPlan(columns: 1, columnWidth: max(width, 0)) }
        var count = max(1, Int((width + spacing) / (minColumnWidth + spacing)))
        if count > 1, count.isMultiple(of: 2) == false { count -= 1 }
        let columnWidth = (width - spacing * Double(count - 1)) / Double(count)
        return GridPlan(columns: count, columnWidth: columnWidth)
    }
}
```

*Measured:* this file typechecks for the iOS 27.1 simulator with `-default-isolation MainActor` (what the app target uses) and without it, and compiles for macOS in Swift 6 mode. The even column count follows the HIG advice to use an even number of grid columns on iPhone Duo ([Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)). Feed it a width you read from the view, never a device size.

## Option A: a `swiftc` script

No package, no test target, no project edits. The app target and the script compile the same files.

```
App/
  Logic/                  plain Swift, part of the app target
    GridPlan.swift
Tools/
  LogicTests/main.swift   the checks
  run-logic-tests.sh      compiles Logic/ + main.swift and runs the result
```

`Tools/LogicTests/main.swift`:

```swift
// Logic tests that run on the Mac. No simulator, no Xcode project.
// Run: Tools/run-logic-tests.sh
import Foundation

var failures = 0

@MainActor func check(_ ok: Bool, _ message: String, line: Int = #line) {
    if ok {
        print("ok   \(message)")
    } else {
        failures += 1
        print("FAIL \(message) (main.swift:\(line))")
    }
}

// Wide window (inner display, open): even column count.
let wide = GridPlan.make(width: 951, minColumnWidth: 150)
check(wide.columns.isMultiple(of: 2), "wide window gets an even column count (\(wide.columns))")
check(wide.columnWidth >= 150, "columns stay at least the minimum width")

// Narrow window (outer display): one or two columns.
let narrow = GridPlan.make(width: 466, minColumnWidth: 200)
check(narrow.columns == 2, "outer-display width fits two columns")

// Edge cases.
check(GridPlan.make(width: 0, minColumnWidth: 150).columns == 1, "zero width falls back to one column")
check(GridPlan.make(width: 120, minColumnWidth: 150).columns == 1, "too narrow for the minimum still shows one column")

print(failures == 0 ? "All checks passed." : "\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
```

- In Swift 6 mode, top-level variables in `main.swift` belong to the main actor. Without `@MainActor` on `check`, the compiler rejects `failures += 1` (*measured*: "main actor-isolated var 'failures' can not be mutated from a nonisolated context").
- The widths 951 and 466 are example inputs, the window widths we saw open and closed on the simulator. They are test data, not constants for the app.

`Tools/run-logic-tests.sh`:

```bash
#!/bin/zsh
# Compiles the app's plain-Swift logic with a small test program and runs it on this Mac.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-27.1.app/Contents/Developer}"
OUT="${TMPDIR:-/tmp}/logic-tests-$$"
xcrun swiftc -swift-version 6 -o "$OUT" App/Logic/*.swift Tools/LogicTests/main.swift
"$OUT"
```

*Measured:* the script prints one `ok` line per check and exits 0. With one check broken on purpose it printed `FAIL outer-display width fits two columns (main.swift:23)` and exited 1, so CI can use the exit code. Compile and run took a few seconds.

`xcrun swiftc` without `-sdk` builds for macOS, which is what you want here.

## Option B: a Swift package with Swift Testing

Use this when several targets share the logic, or when you want parameterized tests, the Xcode test navigator and code coverage.

```
AppCore/
  Package.swift
  Sources/AppCore/GridPlan.swift        same code, with `public` API
  Tests/AppCoreTests/GridPlanTests.swift
```

`Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AppCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "AppCore", targets: ["AppCore"])],
    targets: [
        .target(name: "AppCore"),
        .testTarget(name: "AppCoreTests", dependencies: ["AppCore"]),
    ]
)
```

`Tests/AppCoreTests/GridPlanTests.swift`:

```swift
import Testing
@testable import AppCore

@Suite("Grid plan")
struct GridPlanTests {
    @Test("Wide windows get an even column count", arguments: [700.0, 951, 1100, 1300])
    func evenWhenWide(width: Double) {
        let plan = GridPlan.make(width: width, minColumnWidth: 150)
        #expect(plan.columns.isMultiple(of: 2))
        #expect(plan.columnWidth >= 150)
    }

    @Test func `outer display fits two columns`() {
        #expect(GridPlan.make(width: 466, minColumnWidth: 200).columns == 2)
    }

    @Test func zeroWidthFallsBackToOneColumn() throws {
        let plan = GridPlan.make(width: 0, minColumnWidth: 150)
        try #require(plan.columns == 1)
        #expect(plan.columnWidth == 0)
    }
}
```

Run it on the Mac:

```bash
cd AppCore
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcrun swift test
```

*Measured:* `swift test` built the package and ran 3 tests (one with 4 argument cases) in one suite, all passing, in about 14 seconds from a clean build. It also prints an empty XCTest run ("Executed 0 tests") before the Swift Testing output; that line is normal.

Notes:

- In the package, `GridPlan` and its members are `public` so the app can use them. A package target has no default main-actor isolation, so `nonisolated` is not needed there.
- Backticked names such as `` `outer display fits two columns` `` are raw identifiers. Apple's WWDC26 talk uses them for readable test names ([Migrate to Swift Testing](https://developer.apple.com/videos/play/wwdc2026/267/)).
- `#require` stops the test when it fails, like `continueAfterFailure = false` in XCTest ([Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)).
- Arguments run as separate, parallel test cases. A failure names the argument that failed.
- Add the package to the app project as a local package and `import AppCore` in the app.

## Which one

| | `swiftc` script | Swift package |
|---|---|---|
| Setup | one shell script | `Package.swift`, folders, local package in the project |
| Speed | seconds | seconds after the first build |
| Test style | your own `check` | `@Test`, `#expect`, `#require`, parameterized tests |
| Xcode integration | none | test navigator, coverage, ⌘U |
| Good for | a game engine or a rules file in an app-only repo | shared code across app, widgets and extensions |

Both run on any Mac with Xcode 27.1 and need no simulator. Neither checks the UI; that is the job of the UI tests in [ui-tests.md](ui-tests.md).

## What Swift Testing can't do here

Swift Testing has no UI automation and no performance-testing API. Apple says to keep XCTest for those ([Migrate to Swift Testing](https://developer.apple.com/videos/play/wwdc2026/267/)). So a Duo app usually has Swift Testing (or a script) for logic and an XCTest UI test target for the app. Both kinds can live in one Xcode project, and Swift Testing and XCTest can even share one test target ([Adding tests to your Xcode project](https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project)).
