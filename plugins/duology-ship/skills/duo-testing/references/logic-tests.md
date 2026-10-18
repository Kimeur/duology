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

/// Picks a column count for a grid from its width. When a top-to-bottom fold crosses
/// the grid, active or not, the count is even, so the fold lands in a gap, not on a column.
/// With no fold (closed, or a window the fold doesn't cross), every column that fits.
nonisolated struct GridPlan: Equatable, Sendable {
    var columns: Int
    var columnWidth: Double

    static func make(width: Double, minColumnWidth: Double, foldCrossesGrid: Bool, spacing: Double = 8) -> GridPlan {
        guard width > 0, minColumnWidth > 0 else { return GridPlan(columns: 1, columnWidth: max(width, 0)) }
        var count = max(1, Int((width + spacing) / (minColumnWidth + spacing)))
        if foldCrossesGrid, count > 1, count.isMultiple(of: 2) == false { count -= 1 }
        let columnWidth = (width - spacing * Double(count - 1)) / Double(count)
        return GridPlan(columns: count, columnWidth: columnWidth)
    }
}
```

*Measured:* this file typechecks for the iOS 27.1 simulator with `-default-isolation MainActor` (what the app target uses) and without it, and compiles for macOS in Swift 6 mode.

For grid layouts on iPhone Duo, the HIG suggests an even number of columns so content divides cleanly ([Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)). Like `duo-layout` and `duo-patterns`, `GridPlan` applies that only when a fold crosses the grid. The closed outer display has no fold, so it keeps every column that fits: 3 at 466 pt with a 150 pt minimum, not 2. The fold is an input, never a guess from the width.

### Feed it from the view

The view knows the two inputs; the logic doesn't. Read them from the grid's own geometry. `reservedRegions(kind:options:)` on `GeometryProxy` is iOS 27.1 API ([Apple](https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:))). Pass `.includeInactive` so a flat, open phone still counts its fold and the grid doesn't jump from 5 to 4 columns as someone folds it.

```swift
import SwiftUI

/// The two inputs GridPlan needs, read from the grid's own geometry.
nonisolated struct GridInput: Equatable, Sendable {
    var width: Double = 0
    var foldCrossesGrid = false

    init() {}

    @available(iOS 27.1, *)
    init(_ proxy: GeometryProxy) {
        width = proxy.size.width
        foldCrossesGrid = proxy.reservedRegions(kind: .division, options: .includeInactive).contains { region in
            // A top-to-bottom fold that lies inside the grid, not at its edge.
            region.frame.height > region.frame.width && region.frame.minX > 0 && region.frame.maxX < proxy.size.width
        }
    }
}

@available(iOS 27.1, *)
struct Gallery: View {
    let items: [Int]
    @State private var input = GridInput()

    var body: some View {
        let plan = GridPlan.make(width: input.width, minColumnWidth: 150, foldCrossesGrid: input.foldCrossesGrid)
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(plan.columnWidth), spacing: 8), count: plan.columns),
                      spacing: 8) {
                ForEach(items, id: \.self) { item in Text("\(item)").frame(height: 80) }
            }
            .onGeometryChange(for: GridInput.self) { GridInput($0) } action: { input = $0 }
        }
    }
}
```

*Measured:* this typechecks with `GridPlan` for the iOS 27.1 simulator, with and without `-default-isolation MainActor`. It is a sketch of the wiring: `duo-patterns`' feed-reflow recipe also splits the columns around an active fold. On the simulator, Duology has not checked what `.includeInactive` returns in each pose; the test below covers the maths only.

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

// A fold crosses the grid: an odd count rounds down to even.
let folded = GridPlan.make(width: 800, minColumnWidth: 150, foldCrossesGrid: true)
check(folded.columns == 4, "a fold across the grid turns 5 columns into 4 (\(folded.columns))")
check(folded.columnWidth >= 150, "columns stay at least the minimum width")

// No fold: every column that fits, odd or even.
let flat = GridPlan.make(width: 466, minColumnWidth: 150, foldCrossesGrid: false)
check(flat.columns == 3, "without a fold, 3 columns fit and all 3 stay (\(flat.columns))")

// Edge cases.
check(GridPlan.make(width: 0, minColumnWidth: 150, foldCrossesGrid: true).columns == 1, "zero width falls back to one column")
check(GridPlan.make(width: 120, minColumnWidth: 150, foldCrossesGrid: true).columns == 1, "too narrow for the minimum still shows one column")

print(failures == 0 ? "All checks passed." : "\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
```

- In Swift 6 mode, top-level variables in `main.swift` belong to the main actor. Without `@MainActor` on `check`, the compiler rejects `failures += 1` (*measured*: "main actor-isolated var 'failures' can not be mutated from a nonisolated context").
- The widths are test data, not constants for the app. Each check passes the fold explicitly, so no width stands in for a pose or a device.

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

*Measured* (17 October 2026): the script prints one `ok` line per check and exits 0. With one check broken on purpose it printed `FAIL without a fold, 3 columns fit and all 3 stay (3) (main.swift:23)` and exited 1, so CI can use the exit code. Compile and run took a few seconds.

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
    @Test("A fold across the grid gives an even count", arguments: [466.0, 800, 951, 1100])
    func evenWithFold(width: Double) {
        let plan = GridPlan.make(width: width, minColumnWidth: 150, foldCrossesGrid: true)
        #expect(plan.columns.isMultiple(of: 2))
        #expect(plan.columnWidth >= 150)
    }

    @Test func `without a fold, every column that fits`() {
        #expect(GridPlan.make(width: 466, minColumnWidth: 150, foldCrossesGrid: false).columns == 3)
        #expect(GridPlan.make(width: 800, minColumnWidth: 150, foldCrossesGrid: false).columns == 5)
    }

    @Test func zeroWidthFallsBackToOneColumn() throws {
        let plan = GridPlan.make(width: 0, minColumnWidth: 150, foldCrossesGrid: false)
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

*Measured* (17 October 2026): `swift test` built the package and ran 3 tests (one with 4 argument cases) in one suite, all passing, in about 10 seconds from a clean build. It also prints an empty XCTest run ("Executed 0 tests") before the Swift Testing output; that line is normal.

Notes:

- In the package, `GridPlan` and its members are `public` so the app can use them. A package target has no default main-actor isolation, so `nonisolated` is not needed there.
- Backticked names such as `` `without a fold, every column that fits` `` are raw identifiers. Apple's WWDC26 talk uses them for readable test names ([Migrate to Swift Testing](https://developer.apple.com/videos/play/wwdc2026/267/)).
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
