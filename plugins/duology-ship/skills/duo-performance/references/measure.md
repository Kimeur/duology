# Measuring a fold: duo-fold-cost

`scripts/duo-fold-cost` (Python 3, standard library only) measures what each fold costs your app's main thread on the iPhone Duo simulator. It needs no change to the app. Numbers here were measured on 6 November 2026 with Xcode 27.1 (27A9275); see [evidence.md](evidence.md).

## What `run` does

1. Finds the booted iPhone Duo simulator (or `--udid`). It never creates or boots one.
2. Reads the app's executable name from the installed bundle: Instruments attaches by name. (*Measured:* attaching by the simulator process's pid failed with "Cannot find process for provided pid".)
3. Notes the pose the phone is in, sets the cycle's last pose (closed for the default `open,closed`), and launches the app with your arguments.
4. Starts `xctrace record` with the Hangs and os_signpost instruments (and Time Profiler with `--time-profiler`), attached to the app.
5. For each cycle, sets each pose with `duo-pose set`, then waits `--settle` seconds (default 2).
6. Stops the recording as Ctrl-C would and puts the phone back in the pose it found, also when something failed on the way or you pressed Ctrl-C. Then writes `<trace>.poses.json` (which pose change started when).
7. Exports three tables with `xctrace export` and reads them.

A run of 3 cycles of open and closed records for about a minute (*measured*): each `duo-pose set` took about 10 s.

## Options

| Option | Default | |
|---|---|---|
| `--poses` | `open,closed` | Poses for each cycle, from `closed`, `open`, `book`, `tabletop` |
| `--cycles` | 3 | Use 5 when the folds of one run vary a lot |
| `--settle` | 2 s | Wait after launch and after each pose |
| `--time-profiler` | off | Adds Time Profiler and names the code in each fold's longest stretch; a bigger trace |
| `--out` | `./fold-cost` | Folder for the trace, its log and its pose log |
| `--save FILE` | | The whole report as JSON |
| `--compare FILE` | | A saved report; prints what got slower or faster |
| `--force` | off | Passed to `duo-pose`: go on while UI tests run on this Mac |
| `--json` | off | One JSON object on stdout |
| `-- args` | | Launch arguments for the app |

`read <trace> --process <Name>` reads a trace recorded before: by `run`, or by hand with the same instruments. It uses `<trace>.poses.json` when it's there; without it, folds are numbered instead of named.

## How it finds a fold

UIKit marks each scene resize with a `Window / UpdateSceneMetrics` signpost in the app's process. Resizes less than 1 s apart are one fold. The fold's window runs from 150 ms before the first resize (the app hears of the hinge first) to 500 ms after the last one ends. A pose change that resizes the app in several bursts (tabletop to closed passes through other poses on the simulator) is reported once, with the bursts added up.

Inside the window:

| Column | Source |
|---|---|
| longest | The run loop's `waiting_for_events` intervals on the main thread: each stretch from waking to sleeping again is time the main thread ran without a break. The longest one. |
| busy | The sum of those stretches. |
| >8.3ms | How many stretches were longer than one 120 Hz frame. |
| stalls | UIKit's `UpdateCycle.Stalls / UpdateSequence` signposts: update cycles UIKit itself marked as stalled, and the longest. |
| hangs | The Hangs instrument's `potential-hangs` table on the main thread (its threshold is 100 ms): "Microhang", "Brief Unresponsiveness". |

The summary is the median of each column per pose change (`closed -> open`), so the first fold after launch, the most expensive one (*measured*), doesn't decide it alone. Each fold is listed too.

### The code in the longest stretch

With `--time-profiler`, each fold also lists where the main thread's samples (1 ms apart) fell during its longest stretch. A sample counts for its innermost frame in the app's own binary, leaving out the app's `main`; a sample with none counts as "(system)". Instruments names the app's functions from the binary's symbols when it records, so a Release build from `xcodebuild` worked (*measured*); a stripped binary would give addresses.

```text
in the longest: closure #1 in slowSorted(_:) 79 %, (system) 14 %, partial apply for closure #1 in slowSorted(_:) 3 %
mostly your code: move that work out of body, or after the fold.
```

Mostly "(system)" means SwiftUI and UIKit are laying out or rebuilding many views: a stack that isn't lazy, a `GeometryReader` per row, an `.id` or `if` that rebuilds on resize. *Measured* on `Ledger`: 83 % system on open, with `EntryRow.body` in the rest.

### Accessibility reads are left out

`duo-pose` presses Device Hub's buttons through the Accessibility API, and Device Hub's Accessibility tree reaches into the app on screen. *Measured:* in one recording with two pose changes, the app answered 11,684 Accessibility calls, 2.1 s of main-thread time, all while `duo-pose` looked for the buttons. The last ended about 225 ms before the resize. A stretch with an Accessibility call in it is left out and counted as "skipped".

## Comparing runs

`--compare before.json` flags a pose change as slower when its median `longest` or `busy` grew by at least 25 % and at least 20 ms, and exits 1. It lists what got faster the same way.

*Measured* noise: the same build measured twice gave 29 and 30 ms (longest) and 71 and 72 ms (busy) on open, 14 and 12 ms and 45 and 40 ms on close. Neither run was flagged.

The numbers depend on the Mac. Compare runs made on the same Mac, the same simulator and the same build configuration (Release: Debug adds checks of its own).

## JSON

`--json` and `--save` write one object: `process`, `simulator`, `trace`, `folds` (each with `from`, `to`, `start_s`, `longest_ms`, `busy_ms`, `over_frame`, `stalls`, `stall_longest_ms`, `hangs`, `hang_longest_ms`, `skipped`, `bursts`, and `in_longest` with `--time-profiler`: a list of `name` and `share`), `summary` (each with `fold`, `count`, `longest_ms`, `busy_ms`, `stalls`, `hangs`), `slower` and `faster`. On an error: `{"ok": false, "error": {"code", "message", "hint"}}`.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Done |
| 1 | A fold is slower than the saved run (`--compare`) |
| 2 | Bad arguments |
| 3 | Instruments failed: no recording, no trace, or a table missing |
| 4 | `duo-pose` failed (run `duo-pose status`: Device Hub must show the phone, and the app that runs it needs the Accessibility permission) |
| 5 | No booted iPhone Duo simulator |
| 6 | No fold in the trace: the app wasn't in front, or the trace has no os_signpost data |
| 8 | The app isn't installed on the simulator, or didn't launch |

## Recording by hand

When `duo-pose` can't press the buttons, fold by hand in Device Hub while Instruments records:

```bash
UDID=<the iPhone Duo UDID>
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcrun xctrace record --device "$UDID" \
  --attach MyApp --instrument Hangs --instrument os_signpost --time-limit 60s --output fold.trace
# press Open, wait, press Closed in Device Hub; repeat
scripts/duo-fold-cost read fold.trace --process MyApp
```

With no pose log, the folds come out as "fold 1", "fold 2" in order.

## What Instruments does on the simulator

| Template or instrument | On the iPhone Duo simulator (*measured*) |
|---|---|
| Hangs | Works: hangs on the main thread, and the run loop table this script reads |
| os_signpost | Works: the app's signposts, UIKit's scene and update-cycle signposts, Core Animation's commit signposts |
| Points of Interest | Works, with the StateReporting track ([field.md](field.md)) |
| Time Profiler | Works. `xctrace export` names the app's functions; system frameworks stay addresses. `xctrace symbolicate --dsym` afterwards gave addresses instead of names for the app's frames, so don't run it |
| SwiftUI template | Fails: "Hitches is not supported on this platform.", and the trace has no run data |
| SwiftUI instrument alone | Records, then "Trace file had no SwiftUI data" |
| Hitches | "not supported on this platform" |
| `XCTHitchMetric` in a UI test | No values. `XCTOSSignpostMetric.scrollingAndDecelerationMetric` gave a duration only |

Use the SwiftUI and Hitches instruments, and `XCTHitchMetric`, on a device ([device-checks.md](device-checks.md)).
