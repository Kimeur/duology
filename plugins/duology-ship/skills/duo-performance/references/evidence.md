# Evidence

What we measured for `duo-performance`, on 6 November 2026: Xcode 27.1 (27A9275), the iPhone Duo simulator on iOS 27.1, an Apple silicon Mac, Release builds. No real iPhone Duo.

## The test apps

- **FoldProbe**: a SwiftUI app made from a recipe template (iOS 26.0 target, Swift 6, `MainActor` default isolation). A `LazyVGrid` of 3,000 cells whose column count comes from the width. With the `-slow` launch argument, `body` sorts the 3,000 items by a date string from a `DateFormatter` it creates there, and each cell formats its date in full. It emits an `OSSignposter` event at each width change, and runs the code in [field.md](field.md).
- **Ledger**: the eval fixture of [`duo-performance/cheap-fold`](https://github.com/Kimeur/duology/blob/main/evals/tasks/duo-performance/cheap-fold.md), and a copy fixed by hand.

## The resize steps

FoldProbe's width events while opening (fast mode, one fold): 466 pt at +0 ms, 951 pt at +59 ms, 951 pt at +76 ms, 867 pt at +99 ms. Closing: one event, 382 pt. UIKit's `Window / UpdateSceneMetrics` signposts: three while opening, two to three while closing. Matches `duo-transitions` (382 → 466 → 951 → 867 pt within 50 to 250 ms).

## duo-fold-cost on FoldProbe

`duo-fold-cost run com.duology.foldprobe`, 3 cycles of open and closed, medians:

| Run | closed → open: longest / busy | open → closed: longest / busy | Stalls (open) | Hangs |
|---|---|---|---|---|
| Fast, first run | 29 ms / 71 ms | 14 ms / 45 ms | 1 | 0 |
| Fast, second run, `--compare` the first | 30 ms / 72 ms | 12 ms / 40 ms | 1 | 0 |
| `-slow`, `--compare` the first | 486 ms / 517 ms | 137 ms / 154 ms | 2 | 4 open, 3 closed |

- The second fast run was not flagged; the slow run was, on all four numbers, and exited 1.
- Timing: in the first fast run the six folds started at 3.8, 14.5, 25.3, 36.0, 46.6 and 57.5 s into the recording, so each `duo-pose set` plus the 2 s wait took about 10.7 s, and the folds took about a minute of recording.
- Each open, fast: 71, 17 and 29 ms longest in the first run, 43, 15 and 30 ms in the second. The first fold after launch was the most expensive in both.
- Before the script existed, the same probe recorded by hand (Hangs, os_signpost, Time Profiler) showed, in slow mode, three main-thread hangs of 359, 259 and 178 ms while opening, one per resize step, and one of 145 ms while closing. In fast mode, the open's longest stretches were 68 and 80 ms with stalled update cycles of 65 and 39 ms; that was the first fold after launch.

## Where the longest stretch went

`duo-fold-cost run --time-profiler --cycles 1`:

| App | Longest stretch | In it |
|---|---|---|
| FoldProbe `-slow`, open | 540 ms | `closure #1 in slowSorted(_:)` 79 %, system 14 %, `partial apply for closure #1 in slowSorted(_:)` 3 % |
| FoldProbe `-slow`, close | 127 ms | `closure #1 in slowSorted(_:)` 78 %, system 17 % |
| Ledger untouched, open | 1,735 ms | system 83 %, `EntryRow.body` closures 8 % and 6 % |
| Ledger untouched, close | 1,346 ms | system 81 %, `EntryRow.body` closures 11 % and 6 % |

## Ledger before and after

`duo-fold-cost run com.example.ledger`, 3 cycles, Release:

| Build | closed → open: longest / busy | open → closed: longest / busy | Hangs |
|---|---|---|---|
| Fixture, untouched | 2,913 ms / 4,370 ms | 1,645 ms / 1,683 ms | 6 open, 3 closed |
| Fixed by hand | 86 ms / 115 ms | 15 ms / 45 ms | 1 open (the first fold) |

The fix: a `@Observable` model that sorts, formats and adds up once; the width read once with `onGeometryChange` as a Boolean; `AnyLayout` with one `EntryList`; `LazyVStack`; rows with no `GeometryReader` or formatter; no `.id`. Each open after the fix: 269, 86 and 14 ms longest. `--compare` against the untouched run listed all four numbers as faster. The fixed copy passes every check of the eval task, and duo-lint finds nothing.

## Instruments on the simulator

| What | Result |
|---|---|
| `xctrace record --template SwiftUI --attach <pid>` | "Cannot find process for provided pid", for a pid that `pgrep` showed |
| `--attach <name>` | Attached |
| SwiftUI template | "[Error] Hitches is not supported on this platform.", then `xctrace export --toc`: "Trace is malformed - run data is missing." |
| `--instrument SwiftUI` with Hangs, os_signpost, Time Profiler | Recorded; "[Warning] Trace file had no SwiftUI data"; `swiftui-updates` had 0 rows |
| Hangs | `potential-hangs` rows on the main thread, with type and duration; a `runloop-events` table with each `waiting_for_events` interval |
| os_signpost | The app's signposts; UIKit's `Window / UpdateSceneMetrics`, `UpdateCycle / UpdateSequence`, `UpdateCycle.Stalls / UpdateSequence`, `UIScene.Persisted / InterfaceOrientationUpdate`; Core Animation's `Transaction / Commit` and `Transaction.Stalls / Commit` |
| Time Profiler | Samples every 1 ms. `xctrace export` named the app's own frames (`closure #1 in slowSorted(_:)`, `RootView.body.getter`) with no dSYM step; system frames stayed addresses. After `xctrace symbolicate --dsym FoldProbe.app.dSYM`, the app's frames came out as addresses, apart from two inlined ones |
| `XCTHitchMetric(application:)` with `XCTOSSignpostMetric.scrollingAndDecelerationMetric`, 2 iterations of a fast swipe up and down | Only "Duration (Scroll_DraggingAndDeceleration)": 2.583 s and 2.583 s; no hitch metric in the result bundle |

During `duo-pose set`, the app process answered Accessibility calls (`com.apple.Accessibility` signposts, `AXUIA / Automation`): 11,684 in one recording with two pose changes, 2.1 s of main-thread time in total. They came in bursts before each button press; the last one ended 225 ms before the first resize.

## StateReporting and MetricKit

FoldProbe with the first three code blocks of [field.md](field.md) copied into the app (`PoseState`, `onPoseChange`, `FoldMetrics`), hooked to its root view, recorded with Points of Interest and os_signpost while `duo-pose` set open, book, tabletop and closed:

- The trace had a `StateReportingIntervals` table: `open` (12.5 s), `book` (16.9 s), `tabletop` (7.9 s), then `book`, `tabletop` and `book` for 1.8, 1.9 and 2.2 s while the simulator turned back, then `closed`. Domain `com.duology.foldprobe.pose`. An earlier version of the same code, reading the fold through the recipes' `FoldGeometry`, gave the same sequence.
- The `com.apple.StateReporting.Transition` and `Heartbeat` signposts were in the os_signpost table; the `Fold` intervals from `MetricManager.logHandle(category:)` were not.
- The app built with no warnings for an iOS 26.0 target with the iOS 27 code behind `#available`.

APIs read from the iOS 27.1 SDK (`MetricKit.swiftinterface`, `StateReporting.swiftinterface`) and Apple's documentation JSON for `MetricManager`, `init(enabledStateReportingDomains:)`, `MetricReport`, `SignpostIntervalMetric`, `StateReportingDomain`, `StateReporting` and `StateReporter`, all iOS 27.0.

## Code

Every Swift block in [fixes.md](fixes.md) and [field.md](field.md) typechecks against the iOS 27.1 simulator SDK in Swift 5 mode, Swift 6 mode and Swift 6 with `-default-isolation MainActor`, with no warnings. field.md's blocks are checked together, as one module.

## The script

`tests/test_duo_fold_cost.py`: 32 unit tests with exports written the way `xctrace export` writes them (values once with an id and then by reference, tables that reuse the schema before them, frames and binaries by reference in Time Profiler backtraces), and a fake Mac for `run`. `duo-fold-cost read` gave the same numbers as the hand analysis for the first recordings.
