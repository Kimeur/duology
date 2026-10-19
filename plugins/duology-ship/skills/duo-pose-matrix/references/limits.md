# Limits of the pose matrix

Read this before you promise a user an automatic pose sweep. Each limit says what breaks, how you notice, and what to do.

## It is UI scripting, and Xcode can change it

The tools press Device Hub's buttons the way a screen reader would. They depend on:

- the buttons' English descriptions (`Closed`, `Partially Open`, `Open`, `Rotate Right`) and help text;
- the selected sidebar row's identifier (`TableRow.Device.<UDID>`) or the window title, to find the right window;
- Device Hub keeping these buttons in its toolbar.

None of this is a public interface for scripting. Apple can rename, move or hide any of it in an Xcode update, and Device Hub in another language may use other labels (not tested).

How you notice: `duo-pose list` exits 4 with "Device Hub's window shows no pose buttons" and prints the buttons it can see. Do this: use the manual route (`--manual`), and open an issue with the printed button list.

## The pose belongs to the whole simulator

There is one hinge per simulator. When the tool presses Open, every app and every UI test on that simulator sees the phone open.

- The tools refuse to start while UI tests run. They count two things: an `xcodebuild` process running the `test` or `test-without-building` action anywhere on the Mac (read from `ps`), and a UI test runner app (a bundle ID ending in `.xctrunner`) running inside this simulator (read from `simctl spawn <UDID> launchctl list`). `--force` skips the check, for when the user knows the tests use another simulator.
- They look at the program, not at text in its arguments. A plain `pgrep -f "xctrunner|xcodebuild.*test"` also matches a shell loop that merely contains that text, such as another agent waiting for the simulator, and `xcodebuild build-for-testing`, which only builds. It also misses the runner itself, whose process path ends in `-Runner.app/<Name>-Runner` (*measured* on 18 October, with another session's UI tests running on the shared simulator).
- Before each later pose and before the restore, the matrix checks again and waits up to `--busy-wait` seconds. If tests still run, it stops, writes what it has, does not restore the pose (so it doesn't move the screen under the tests a second time), and exits 1. The restore note in `summary.md` names the pose it left.
- Launching your app takes the screen from whatever ran before. The matrix flags a shot `check` when another app starts during a capture, but it can't see which app is in front.
- Our research runs saw this happen: another session's UI tests started in the pose we had left, and someone pressed Open in Device Hub in the middle of a book capture.

## Other scripts that drive the same simulator

Duology's tools take a lock per simulator, so two `duo-pose` or `duo-pose-matrix` runs never interleave. A script of your own that presses Device Hub's buttons or relaunches the app doesn't take that lock.

On 18 October another agent ran its own pose sweep on the shared simulator at the same time as ours (*measured*). It relaunched our app and pressed Closed in the middle of our captures. Before the checks below existed, that produced a blank frame and a Home Screen frame marked `ok`. Now each shot is checked after the screenshot:

- the displays and the device orientation still fit the pose, or the shot fails;
- the app's process is the one we launched, or the shot is marked `check`;
- the picture isn't nearly blank, or it is retaken once and then marked `check`.

These checks find interference, but they can't prevent it. Run one pose sweep per simulator at a time, and use `duo-pose` in your own scripts so they share the lock.

## Permission is the user's decision

macOS gives Accessibility access per app, in System Settings > Privacy & Security > Accessibility ([Apple](https://support.apple.com/guide/mac-help/mh43185/mac)). An app with that access can read and press anything on screen, in every app. That is a real grant of trust, and only the user should make it.

- The tools check without a prompt and never open System Settings, call `tccutil` or change any setting. A test in `tests/` fails if the code ever does.
- If the check fails, tell the user what the permission allows, how to grant it, and that the manual route works without it. Don't press for an answer.
- The permission covers every process the trusted app starts, so the agent's other commands run with it too. Say so if the user asks.

## The window must be visible

The tools find Device Hub's window through Accessibility, which listed no windows for Device Hub while its window was off the current desktop and Mission Control was open (*measured*). Expect the same when the window is minimized, on another Space or in full screen elsewhere (not tested one by one).

- `duo-pose set` and the matrix run `open -a DeviceHub.app` and wait up to 10 seconds. That brings Device Hub to the front and moves the user's keyboard focus to it. Warn the user first. `--no-bring-forward` turns this off. `duo-pose status` and `list` do this only when you pass `--bring-forward`.
- If the screen is in Mission Control, behind a system dialog, or locked, `open -a` may not bring the window back (*measured* on 18 October: Device Hub became the active app, but Mission Control and a system authentication dialog stayed on screen and the window stayed hidden). Never click, type or press Escape to get past a system dialog. Report it and use the manual route, or try again later.

## Open and book look the same from outside

Both show the inner display, held wide, at the same size. Device Hub doesn't report the pose: its sidebar image stayed "Closed" after Open was pressed. So without help from the app, the tools can only say "open or book".

- With `--readout-id`, the app's own readout settles it (see [pose-readout.md](pose-readout.md)).
- Without it, look for the fold in the picture, for example with a region overlay.
- At the end of a run, a phone that started open or in book is left open (flat), and the summary says so.

## Timing can drift

The waits (5 s after a fold button, up to 20 s for the displays to switch) come from runs on one Mac. A slow or busy Mac, a first boot, or a heavy app can take longer.

How you notice: a shot `failed` with "the inner display should be active" or a size mismatch, or an app that hasn't drawn yet. Do this: for a pose that didn't take, raise the matrix's `--pose-wait` and `--timeout` (or `duo-pose set --wait` and `--timeout`); for an app that hasn't drawn, raise the matrix's `--wait`. Then run again.

## What the matrix doesn't capture

- Closed and turned sideways, and open held tall but flat. Set them by hand in Device Hub and take a screenshot with `xcrun simctl io <UDID> screenshot`.
- Hinge angles between the three buttons (Option-drag the slider in Device Hub).
- Split View and Picture in Picture.
- The fold and unfold animation. Record it with `xcrun simctl io <UDID> recordVideo --display=primary-1`.
- Anything on a real iPhone Duo. The simulator's poses are a model of the hardware; hinge feel and camera handover need the device.
