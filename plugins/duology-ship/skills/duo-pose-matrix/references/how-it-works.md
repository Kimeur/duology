# How duo-pose and duo-pose-matrix work

Labels: *measured* means we ran it on the shared iPhone Duo simulator (iOS 27.1, Xcode 27.1 27A9275, macOS 27.0.1) on 17 or 18 October 2026. *Unverified* means we could not run it yet.

## The pieces

| File | Language | Job |
|---|---|---|
| `scripts/duo-pose`, `scripts/duo_pose.py` | Python 3.9+ | Finds the simulator, reads its displays, decides which buttons to press, checks the result. |
| `scripts/duo-pose-matrix`, `scripts/duo_pose_matrix.py` | Python 3.9+ | Loops over poses and cases, launches the app, takes screenshots, writes the summary. |
| `scripts/duo-pose-ax.swift` | Swift (macOS) | Talks to Device Hub through the Accessibility API: `trust`, `buttons`, `press`, `readout`. Prints one JSON object per call. |

The Python side builds the Swift file on first use with `xcrun --sdk macosx swiftc -O` into `~/Library/Caches/duology/duo-pose-ax-<hash>/` (or `$DUOLOGY_CACHE_DIR`). The hash comes from the Swift source, so an update builds a fresh copy. No binary is committed. To clear it, delete that cache folder by hand.

Every command the tools run goes through one `System` object, so the unit tests in `tests/` replace the Mac with a fake phone and run on Linux.

## Accessibility, step by step

1. **Trust check, no prompt.** `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt` set to false. It returns whether macOS lets this process (and the app that started it) use Accessibility, and never shows a dialog ([AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions), [kAXTrustedCheckOptionPrompt](https://developer.apple.com/documentation/applicationservices/kaxtrustedcheckoptionprompt)). The permission belongs to the app that runs the agent: a helper started from a trusted Terminal or Claude app is trusted too (*measured*: `{"trusted":true}` from a helper built and run by the agent).
2. **Find Device Hub.** `pgrep -x DeviceHub` gives its process ID. Device Hub lives in `Xcode-27.1.app/Contents/Applications/DeviceHub.app` (bundle ID `com.apple.dt.Devices`).
3. **Find the window for this simulator.** The helper walks each window's tree. A window whose selected sidebar row has the identifier `TableRow.Device.<UDID>` wins. Otherwise a window whose title starts with the simulator's name. A window that shows another device is skipped.
4. **Find the buttons.** It looks for `AXButton` elements whose description is `Closed`, `Partially Open`, `Open` or `Rotate Right`, and whose help text is the same word. Device Hub's own toolbar buttons have both; buttons mirrored from the app on screen don't, so an app button labelled "Open" is never pressed. It prefers the group that holds all three pose buttons.
5. **Press.** `AXUIElementPerformAction(button, kAXPressAction)` ([AXUIElementPerformAction](https://developer.apple.com/documentation/applicationservices/1462091-axuielementperformaction)).

The button list came from a tree dump on 17 October (*measured*):

```text
AXButton desc="Rotate Right"    help="Rotate Right"
AXButton desc="Closed"          help="Closed"
AXButton desc="Partially Open"  help="Partially Open"
AXButton desc="Open"            help="Open"
```

They have no accessibility identifier. Apple's Device Hub article describes the same three pose buttons and the Option-drag slider ([Interacting with your app in Device Hub](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)).

## Poses and buttons

| Pose | Buttons | Active display | Device orientation | Display rotation (gallery on screen) | Screenshot |
|---|---|---|---|---|---|
| closed | Closed | outer (`LCD`, primary) | `portrait` | `rot0` | `--display=primary`, 1398 x 2034 px |
| open | Open | inner (`LCD-1`) | `portrait` | `rot90` (held wide) | `--display=primary-1`, 2853 x 2007 px |
| book | Partially Open | inner | `portrait` | `rot90` | `--display=primary-1`, 2853 x 2007 px |
| tabletop | Partially Open, then Rotate Right once | inner | a landscape value | `rot180` (held tall) | `--display=primary-1`, 2007 x 2853 px |

*Measured* on 17 and 18 October with the gallery app. Three more Rotate Right presses bring the phone back to portrait.

### How it knows which way the phone is turned

Two readings exist, and they can disagree:

- **The device's orientation**, from `xcrun devicectl device orientation get -d <UDID>` (`deviceOrientation`: `portrait`, `landscapeLeft`, `landscapeRight`, `portraitUpsideDown`). It follows Device Hub's Rotate Right whatever app is on screen.
- **Each display's `currentOrientation`** (`rot0` to `rot270`) in `devicectl device info displays`. It follows the app on screen. A portrait-only app, or the Home Screen, keeps the outer display at `rot0` while the device is turned.

*Measured* on 18 October: the outer display read `rot0` with another app on screen, then our gallery launched, turned to landscape, and the screenshot came out 2034 x 1398. The device had been left turned, probably by another session's UI test.

So the tools judge "portrait" or "turned" by the device's orientation, and use the display's rotation only for the screenshot's expected size, read right after the screenshot. They press Rotate Right one at a time, read the orientation after each press, and stop after four presses, so they never depend on which landscape comes first. Tabletop accepts either landscape value: both hold the inner display tall with the fold across.

When it closes a turned phone, it turns it back to portrait first, while the inner display still shows, then presses Closed. When it restores the start pose, it turns the device back to its exact start orientation.

## Checking the pose

Device Hub doesn't report the pose. Its sidebar image kept saying Closed after Open was pressed, and its pose buttons report no value or selected state (*measured*). So the tools check from the outside:

1. **Active display and orientation.** The active display comes from `xcrun devicectl device info displays -d <UDID> --json-output <file>` (each display has `active`, `primary`, `currentOrientation` and `nativeSize`); the orientation from `devicectl device orientation get`. The tools expect the outer display for closed and the inner one for the others, in the orientation listed above.
2. **Screenshot size.** The expected size is the active display's `nativeSize`, swapped at `rot90` and `rot270`, read just after the screenshot. `duo-pose set` takes a test screenshot into a temporary folder and deletes it; the matrix checks each real screenshot.
3. **Nothing moved during the capture.** The matrix reads the displays and orientation again after each screenshot. If the pose no longer fits, the shot fails: someone else pressed Device Hub's buttons or a UI test turned the device.
4. **The app is running, and it is the copy we launched**, from `xcrun simctl spawn <UDID> launchctl list` (the `UIKitApplication:<bundle id>` job and its process ID). A missing process usually means a crash in that pose. A different process ID than the one `simctl launch` printed means someone else relaunched or reinstalled the app, so the shot is marked `check`. A relaunch leaves the old job listed with no process next to the new one; the tools read the running one.
5. **No other app started** during the capture. A third-party app job that appears or restarts between the snapshots before and after the screenshot marks the shot `check`.
6. **Not blank.** A PNG under 0.03 bytes per pixel is nearly one colour, usually an app that hasn't drawn yet. The matrix waits `--wait` seconds once more and retakes it; if it is still nearly blank, the shot is marked `check`. *Measured*: a blank launch frame with only the status bar was 0.026 bytes per pixel; real gallery screens were 0.09 to 0.19.
7. **The fold**, only with `--readout-id`. See [pose-readout.md](pose-readout.md).

Open and book pass checks 1 and 2 the same way. That is why the summary marks their fold "not checked" without a readout.

## One run per simulator

`duo-pose set` and `duo-pose-matrix` hold a lock file per simulator (`<cache>/locks/<UDID>.lock`, with `flock`) for the whole run. A second run on the same simulator exits 6 at once instead of waiting. The lock only keeps Duology's tools apart. Other scripts that press Device Hub's buttons don't take it; checks 3 and 4 catch them.

## Timing

| Wait | Default | Why |
|---|---|---|
| After a fold button | 5 s (`duo-pose set --wait`, the matrix's `--pose-wait`) | Open and Partially Open settled in 4 to 6 s (*measured*). Open to book changes no display, so the tool can't poll for it. |
| For the displays to switch | up to 20 s (`--timeout` on both tools) | Closed once took between 5 and 9 s (*measured*). The tool polls `devicectl` every second. The matrix's restore uses the same two waits. |
| After Rotate Right | 1.5 s, then poll | |
| Before the check | 1.5 s | Lets the app finish its layout. |
| Launch to screenshot (matrix) | 4 s (`--wait`) | A first launch after install can be slower. |

## Files the matrix writes

In `--out` (default `$TMPDIR/duo-poses/<bundle id>-<time>/`):

- `<case>-<pose>.png`, one per case and pose. Case names keep only letters, digits, dot, dash and underscore.
- `summary.json`: `bundleId`, `simulator`, `mode` (`automatic`, `manual` or `mixed`), `startPose`, `endPose`, `restoreNote`, `cases`, `skipped`, `stopped`, and `shots`. Each shot has `case`, `args`, `pose`, `file`, `display`, `size`, `expectedSize`, `checks` (`pose`, `size`, `appRunning`), `fold`, `foldNote`, `status`, `notes`, `review` and `takenAt`.
- `summary.md`: the same as a table, plus the rules to review.

A `--manual` run in a folder that already has a `summary.json` for the same app adds to it, replacing an earlier shot of the same case and pose.

## Order of a run

1. Pick the simulator: the UDID you pass, else the booted one named "iPhone Duo", else any booted iPhone Duo. Stop if it isn't booted.
2. Stop if UI tests run (unless `--force`) or the app isn't installed. "UI tests run" means an `xcodebuild test` or `test-without-building` process on the Mac, or an `.xctrunner` app running in the simulator (see [limits.md](limits.md#the-pose-belongs-to-the-whole-simulator)).
3. Read the start pose. Connect to Device Hub (bringing it forward if needed).
4. For each pose: check for UI tests again, press the buttons, check the pose; then for each case launch the app with `simctl launch --terminate-running-process`, wait, take the screenshot and check it. With `--no-relaunch` the loops swap: each case launches once and stays running through every pose.
5. Check for UI tests again (waiting up to `--busy-wait`), then restore the start pose. If tests still run, skip the restore and record why. Quit the app (`simctl terminate`), read the end pose, write the summary.

## What we checked

On 18 October 2026, on the shared iPhone Duo simulator, with other agents building, testing and taking screenshots on it at the same time:

| Check | Result |
|---|---|
| Unit tests (`python3 -m unittest discover` on the `tests/` folder), Python 3.11 and Xcode's Python 3.9 | All pass; the Swift build test skips itself unless `DUO_POSE_SWIFT=1` |
| Swift build test with `DUO_POSE_SWIFT=1` | Passes: the helper builds with Xcode 27.1 and answers `trust` |
| `duo-pose status` and `list` | Found the window "iPhone Duo – iOS 27.1" and the four buttons, which report no value or selected state; read trust (allowed), the pose and the UI test check |
| Automatic run 1 (gallery, two cases, four poses) | The tool pressed Closed, Open, Partially Open, then Partially Open and Rotate Right, and restored closed. The overlay in the pictures confirmed every pose: no fold closed, "Fold, inactive" open, "Fold, active" down the middle in book and across in tabletop. Another agent was sweeping the same simulator at the same minute and relaunched the gallery three times: one frame came out blank and one showed the Home Screen, both marked `ok`, and one good frame was marked "not running". Those three mistakes led to the process, blank-frame and stale-job checks above. |
| Automatic run 2 | The closed frames came out turned, 2034 x 1398: the device had been left turned while a portrait-only app showed the outer display upright. The tool flagged both shots `failed`; this led to judging the orientation by the device, not the display. Open and book were correct. The window left the desktop before tabletop (the user switched Spaces), so the run stopped and restored closed. |
| Automatic run 3, final code | All four poses pressed and checked; closed, book and tabletop frames `ok`. Both open frames `failed` with "the pose changed during the capture": another agent's script pressed Closed during the capture, and the blank-frame check fired too. The start pose (open, set by someone else) was restored. |
| `--manual closed`, two cases | Two correct 1398 x 2034 frames, both `ok` |
| `--manual book` while the phone was closed | `failed`: "the inner display should be active for book, but the outer one is"; exit 1 |
| An app that isn't installed | Exit 8, nothing written |
| `set` while another session ran `xcodebuild test-without-building` | Refused with exit 6 and named the xcodebuild process and the runner app |
| `set` with Device Hub's window off the current desktop and `--no-bring-forward` | Exit 4 with the manual instructions; nothing pressed |
| `--readout-id` against Device Hub | *Unverified*: tested only against the fake simulator |
