# Fixtures

Starting points for the eval tasks. `run.sh` copies one fixture folder into a fresh work folder outside the repo, commits it to a throwaway git repo, and runs the agent there. The agent sees only that folder's contents, never this file and never the task file.

Rules for fixtures:

- **Each app builds** for the iPhone Duo simulator with Xcode 27.1 before any agent touches it. Check with the command at the end of this page.
- **Nothing inside a fixture names its mistakes.** No "naive", no "bug", no comments that point at the problem. Comments read like a normal app's comments. The app names are neutral too, so neither arm gets a hint.
- **No Duology words inside a fixture.** The run without Duology must not learn that Duology exists from the files it works on.
- The projects use Xcode's synchronized folders (`objectVersion = 77`): a Swift file added under the app folder joins the target without a project edit.

## Places

A list app, written the way many apps were before iPhone Duo. Used by most layout, navigation, continuity, testing and lint tasks, including the README task "Make an existing list app work on Duo".

- iOS 17.0 target, Swift 5 mode, `TARGETED_DEVICE_FAMILY = 1,2`, one UI test target (`PlacesUITests`) with one launch test.
- Three tabs: Places (search, sort, list and detail), Gallery (a grid), Settings.

Planted mistakes:

| Where | Mistake | Caught by |
|---|---|---|
| `App/RootView.swift` | `UIDevice.current.userInterfaceIdiom == .pad` picks the text size | duo-lint DUO004 |
| `List/PlacesScreen.swift` | `sizeClass == .regular` treated as iPad | DUO005 |
| `List/PlacesScreen.swift` | an `if` on size class swaps two layouts that each own the search text, sort order and selection: a fold throws them away | `single_owner.py`, checklist R2 |
| `List/PlacesScreen.swift` | the wide layout pins the list to `.frame(width: 390)` | DUO007, R3 |
| `List/PlacesScreen.swift` | a floating + button centred at the bottom of the whole screen: on the open phone it sits on the fold | task checks, R4 |
| `List/PlacesScreen.swift` | a text-only "Edit" button and an icon-only sort menu in the toolbar | task checks, R6 |
| `List/PlaceRow.swift` | thumbnail sized from `UIScreen.main.bounds` | DUO001 |
| `List/PlaceDetail.swift` | `GeometryReader` width compared to 375; header height from `UIScreen.main.bounds` | DUO009, DUO001 |
| `List/PlaceDetail.swift` | its own bottom bar (`safeAreaInset(edge: .bottom)`) instead of toolbar items | task checks, R6 |
| `Gallery/GalleryScreen.swift` | 3 or 5 columns picked from `UIDevice.current.orientation` | DUO002, R5 |
| `Support/Diagnostics.swift` | `UIScreen.main.scale` in a bug-report string; not layout, so fixing or silencing with a reason are both fine | DUO001 |
| `Places.xcodeproj` | `INFOPLIST_KEY_UIRequiresFullScreen = YES` (Debug and Release) | DUO008 |

duo-lint on the untouched fixture: 10 findings, 3 errors and 7 warnings.

`List/PlaceFilter.swift` and `List/Place.swift` are plain Swift (Foundation only), so logic tests can compile them on the Mac.

## Reel

A video player with an "Up next" list. Used by the README task "Keep video playing through fold and unfold" and by [`duo-media/picture-in-picture`](../tasks/duo-media/picture-in-picture.md).

- iOS 17.0 target, Swift 5 mode. No test target.
- `Media/clip.mp4`: a 60-second, 480 × 270 test pattern with a running counter (made with ffmpeg's `testsrc` source, 148 KB), so a restart is easy to see.

Planted mistakes: an `if` on size class builds a separate `VideoPane` in each branch, and each `VideoPane` owns its `AVPlayer` in `@State` and pauses it in `onDisappear`, so a fold restarts the video; the video height comes from `UIScreen.main.bounds` (DUO001); the list has `.frame(width: 320)` (DUO007).

## Talk

A video call screen with placeholder videos. Used by the README task "Tabletop layout for a video call".

- iOS 17.0 target, Swift 5 mode. No test target.
- Four controls with identifiers `call.mute`, `call.camera`, `call.speaker`, `call.end`.

Planted mistakes: the self view is sized from `UIScreen.main.bounds` (DUO001, twice); the controls change with `UIDevice.current.orientation` (DUO002); the layout ignores the fold.

## TapDuel

A two-player tap race. Used by `duo-shared-screen/both-halves-always`.

- iOS 27.1 target, Swift 6, main-actor isolation by default. No test target.
- The game rules live in `Duel/DuelModel.swift`.

Planted mistake: the two halves are the two sides of an `ArrangementView` with `.split` style. Closed and held sideways, a split arrangement shows only its primary view (measured by Duology on the iOS 27.1 simulator; see the `duo-layout` skill). duo-lint finds nothing: this mistake needs a person or a task check.

## Starter

An empty SwiftUI app ("Hello") for tasks that build something new inside an existing project. Used by [`duo-shared-screen/face-to-face-quiz`](../tasks/duo-shared-screen/face-to-face-quiz.md), [`duo-reading/two-facing-pages`](../tasks/duo-reading/two-facing-pages.md) and [`duo-games/fill-every-pose`](../tasks/duo-games/fill-every-pose.md).

- iOS 26.0 target, Swift 6, main-actor isolation by default, approachable concurrency.
- A UI test target, `StarterUITests`, with one launch test. Oracle tests from [`../oracles`](../oracles) are copied into it after the agent's run.

## Tally

An expense list in UIKit, written the way apps were before iPhone Duo and still built with an older Xcode. Used by [`duo-migrate/ship-on-duo`](../tasks/duo-migrate/ship-on-duo.md).

- iOS 16.0 target, Swift 5 mode, `TARGETED_DEVICE_FAMILY = 1,2`, one UI test target (`TallyUITests`) with one launch test.
- A table of expenses under a total, swipe to delete, a + button that adds one through a "New Expense" alert, and a detail screen pushed in a `UINavigationController`. The list is saved to `Documents/expenses.json`; the first launch shows six sample expenses.
- CI: `.xcode-version` and `.github/workflows/build.yml`, both pinned to Xcode 26.4.

Planted mistakes:

| Where | Mistake | Caught by |
|---|---|---|
| `App/AppDelegate.swift` | no scene life cycle: an `@main` app delegate makes its window with `UIWindow(frame: UIScreen.main.bounds)` in `didFinishLaunching` | the launch crash below, task checks `scene-life-cycle` and `launches`, DUO001 |
| `Tally.xcodeproj` | `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = NO` (Debug and Release), so the app has no scene manifest | the launch crash, `launches` |
| `App/AppDelegate.swift` | the list is saved in `applicationDidEnterBackground`, which UIKit no longer calls once the app uses scenes | task check `still-saves-in-background` |
| `List/ExpenseListViewController.swift` | header height from `UIScreen.main.bounds` | DUO001, R3 |
| `List/ExpenseListViewController.swift` | header layout picked from `UIDevice.current.orientation` | DUO002, R3 |
| `List/ExpenseCell.swift` | row icon size from `UIScreen.main.bounds` | DUO001, R3 |
| `Detail/ExpenseDetailViewController.swift` | `userInterfaceIdiom == .pad` puts the icon beside the details | DUO004, R3 |
| `Detail/ExpenseDetailViewController.swift` | `view.bounds.height <= 667` picks the icon size | DUO006, R3 |
| `Tally.xcodeproj` | `INFOPLIST_KEY_UIRequiresFullScreen = YES` (Debug and Release) | DUO008, task check `full-screen-off`, R1 |
| `Tally.xcodeproj` | `IPHONEOS_DEPLOYMENT_TARGET = 16.0`. Xcode 27.1 builds it without a warning (measured), but every iOS 27 API then needs `if #available` | the build gate, when an agent forgets the check |
| `.xcode-version`, `.github/workflows/build.yml` | CI pinned to Xcode 26.4 (`26.4`, `DEVELOPER_DIR: /Applications/Xcode_26.4.app/Contents/Developer`) | task check `ci-on-xcode-27-1` |

duo-lint on the untouched fixture: 8 findings, 3 errors and 5 warnings.

Measured on 23 October 2026 with Xcode 27.1 (27A9275) on the iPhone Duo simulator (iOS 27.1): the fixture builds with the iOS 27.1 SDK and crashes at launch, every time. Three launches (`simctl launch`, `launch_ok` and a UI test) each left a crash report in `~/Library/Logs/DiagnosticReports`: `EXC_BREAKPOINT (SIGTRAP)`, "Trace/BPT trap: 5", on the main thread in UIKitCore `___UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption_block_invoke`, called from `-[UIApplication workspace:didCreateScene:withTransitionContext:completion:]`, 1.7 to 7 seconds after the process started. A hand-fixed copy (a scene delegate connected through `configurationForConnecting`, a generated scene manifest, no `UIRequiresFullScreen`, CI on 27.1, the lint findings fixed) launches and passes every check of the task.

## Fixtures added for v0.2

Each of these is used by one or two v0.2 tasks, and four of them by v0.3 tasks too. The planted problems are listed in the task's "Starting point" section, so they aren't repeated here. All seven build for the iPhone Duo simulator (`build-for-testing`, 18 and 19 October 2026), and every task that uses them fails on the untouched fixture (`run.sh --selftest --with-build`).

| Fixture | What it is | Target | Used by |
|---|---|---|---|
| `Steps` | A recipe step, a timer panel and Previous and Next buttons | iOS 17, Swift 5 | [`duo-postures/book-two-regions`](../tasks/duo-postures/book-two-regions.md), [`duo-system-surfaces/timer-live-activity`](../tasks/duo-system-surfaces/timer-live-activity.md) |
| `Album` | An album screen with a cover, a track list and a player bar | iOS 17, Swift 5 | [`duo-transitions/fold-without-reload`](../tasks/duo-transitions/fold-without-reload.md) |
| `Trail` | A drawn map, a stats panel and three map buttons, with `TrailUITests` | iOS 17, Swift 5 | [`duo-ergonomics/thumb-reach`](../tasks/duo-ergonomics/thumb-reach.md) |
| `Inbox` | A mail inbox: list and message side by side open, a push closed, with `InboxUITests` | iOS 17, Swift 5 | [`duo-accessibility/voiceover-two-panes`](../tasks/duo-accessibility/voiceover-two-panes.md), [`duo-accessibility/large-text-closed`](../tasks/duo-accessibility/large-text-closed.md) |
| `Trips` | A grid of trip cards built literally from two design frames (`Design/frames.md`), with `TripsUITests` | iOS 17, Swift 5 | [`duo-design-system/tokens-from-two-frames`](../tasks/duo-design-system/tokens-from-two-frames.md), [`duo-swiftui-27/reorder-and-swipe-grid`](../tasks/duo-swiftui-27/reorder-and-swipe-grid.md) |
| `Notes` | A notes list that pushes an editor, one window only | iOS 26, Swift 6, main-actor isolation by default | [`duo-scenes/open-in-new-window`](../tasks/duo-scenes/open-in-new-window.md), [`duo-intelligence/ai-pane-through-fold`](../tasks/duo-intelligence/ai-pane-through-fold.md), [`duo-app-intents/open-note-from-siri`](../tasks/duo-app-intents/open-note-from-siri.md) |
| `Shoot` | A full-screen rear camera preview with a record button and a countdown | iOS 17, Swift 5 | [`duo-scenes/camera-subject-view`](../tasks/duo-scenes/camera-subject-view.md), [`duo-camera/front-camera-switch`](../tasks/duo-camera/front-camera-switch.md) |

## review-shots

Two real screenshots of `Places`, taken on the iPhone Duo simulator (Xcode 27.1, iOS 27.1) with the phone closed and upright: the list and a detail screen (1398 × 2034 px, the outer display). `frames.md` says what each shows. Used by `duo-design-review/screenshot-review`.

They show what the system did with the app's bars: the tab bar and the icon-only sort button went into the vertical side bar, the text-only "Edit" button stayed in a horizontal bar at the top, the floating + button covers a row, and the detail screen's own bottom bar runs under the system's vertical tab bar.

## review-concept

`concept.md`: a written design spec for a recipe app, four frames, with seven planted problems and one line that is fine. Used by `duo-design-review/concept-review`; the task file lists the problems.

## empty

Not a folder. `fixture: empty` starts the agent in an empty folder. Used by `duo-setup/mac-check` and the five recipe tasks.

## Check that every fixture builds

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer
UDID=<an iPhone Duo simulator UDID>   # xcrun simctl list devices | grep "iPhone Duo"
cd evals/fixtures
for app in Places Reel Talk TapDuel Starter Steps Album Trail Inbox Trips Notes Shoot Tally; do
  xcodebuild build-for-testing -project "$app/$app.xcodeproj" -scheme "$app" \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "/tmp/fixture-dd/$app" CODE_SIGNING_ALLOWED=NO -quiet && echo "$app ok"
done
```

Then run `evals/run.sh --selftest` to confirm every task still fails on its untouched fixture.

`run.sh` builds under `env -i` with an empty `HOME`, so a fixture must not depend on anything in your account (a user-level Swift package cache, a signing identity, an environment variable). On 17 October 2026 the first five built for the iPhone Duo simulator that way with `build-for-testing`; the seven v0.2 fixtures built the same way through `run.sh --selftest --with-build` on 18 and 19 October 2026.
