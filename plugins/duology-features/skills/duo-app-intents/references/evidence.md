# Evidence

What we ran for this skill and what came out. Everything here is *measured* unless a line says otherwise.

## Setup

- Xcode 27.1 (27A9275), iOS 27.1 simulator SDK, the shared "iPhone Duo" simulator (iOS 27.1). A MacBook Pro with an Apple M2, macOS 27.0.1. 20 October 2026.
- A probe app (deployment target iOS 27.1, Swift 6, `UIApplicationSupportsMultipleScenes` set to `YES`) with three notes, Groceries, Trip and Ideas, in a `NavigationSplitView`:
  - `NoteEntity` with an `EntityStringQuery`;
  - `OpenNoteIntent: OpenIntent, TargetContentProvidingIntent`, handled with `onAppIntentExecution` on the window root, which sets the window model's selection, and `handlesExternalEvents(preferring: [], allowing: ["*"])`;
  - `SummarizeNoteIntent` with `supportedModes = .background`, returning a value and a dialog;
  - the list annotated with `appEntityIdentifier(forSelectionType:identifier:)`, the detail with `appEntityIdentifier(_:)`.
- A UI test bundle with AppIntentsTesting ran the intents and read `viewAnnotations()`. The app logged scene phase, size class, the handler and `perform()` with `os.Logger`.
- Poses set with `duo-pose` before each run. Other agents' apps shared the simulator; where another app took the front during a run, we say so and rely on our app's own scene-phase log.

## Runs

### Closed

| Step | Result |
|---|---|
| Launch | Compact width, list showing. Annotations: none in the first run, the three rows in the second. |
| Run `OpenNoteIntent(target: "Trip")` | `onAppIntentExecution` ran (scene active, compact), then `perform()` 0.9 s later in the first run and 1.7 s later in the second, reporting `IntentMode.foreground`. The split view collapsed to the note: the Trip row no longer existed and the detail title read "Trip". Annotations: one, Trip. |
| `XCUIDevice.shared.press(.home)` (first run) | No change: the app stayed `.runningForeground` and the scene stayed active. |
| Activate Settings instead (second run) | Scene went inactive, then background. |
| Run `SummarizeNoteIntent(note: "Trip")` from the background | `perform()` reported `IntentMode.background` and `isVoiceOnly == false`. The scene stayed in the background; XCUI reported `.runningBackground`. The on-device model call inside it failed (see `duo-intelligence` evidence); the test got the error. |
| Run `OpenNoteIntent(target: "Ideas")` from the background | Scene inactive, the handler ran (phase still inactive), the scene became active 0.1 s later, then `perform()`. Same window: the window root's first-appearance log didn't repeat. Detail title "Ideas". Annotations: one, Ideas. |

### Open

| Step | Result |
|---|---|
| Launch | Regular width, list showing. Annotations: none. |
| Run `OpenNoteIntent(target: "Trip")` | Handler (scene active, regular), then `perform()` 0.4 s later. List and detail side by side: the Trip row stayed visible and the detail read "Trip". Annotations: four, Groceries, Trip, Ideas and Trip. `isSelected` was `false` for all four. |
| Activate Settings, run `SummarizeNoteIntent` | `perform()` reported the background mode; our scene stayed in the background (scene-phase log). |
| Run `OpenNoteIntent(target: "Ideas")` from the background | Handler while inactive, scene active, then `perform()`. Detail read "Ideas"; annotations: Groceries, Trip, Ideas and Ideas. Another agent's app was in front on the simulator at the end of this run, so XCUI's `app.state` for this step is not reliable. |

## Build check

Typechecking doesn't run the App Intents metadata step, which validates intents, entities and App Shortcut phrases at build time. So we built the skill's code in an app target with `xcodebuild` (Xcode 27.1, iOS 27.1 simulator):

- SKILL.md sections 1 to 6 plus [running-modes.md](running-modes.md): built with no errors or warnings. The metadata step exported four intents (`AppendToNoteIntent`, `OpenNoteIntent`, `ReadNoteSummaryIntent`, `ShowNoteSnippetIntent`), the `NoteEntity` and both App Shortcuts with their phrases.
- The same plus the UIKit `OpenNoteInSceneIntent` from [routing.md](routing.md): failed in the metadata step, because two `OpenIntent` types targeted `NoteEntity`. With the UIKit intent instead of the SwiftUI one, it built.

## What we read from it

- Setting the window model's selection in `onAppIntentExecution` is enough on both displays. The split view picked the layout; the intent code had no size-class check.
- The handler runs before the scene is active when the app comes from the background, so the window is ready on its first frame.
- A `.background` intent left the app behind, closed and open.
- Open, the list and the detail both report the open note.
- `isSelected` stayed `false` for the selected row.

## Not covered

- Siri, Shortcuts and the Action button themselves; we drove the intents with AppIntentsTesting only.
- Two windows of the app on the inner display, and closing the phone with both open.
- UIKit routing (`UISceneAppIntent`, `AppIntentSceneDelegate`, activation conditions); the UIKit code in [routing.md](routing.md) typechecks and builds but didn't run.
- Book and tabletop poses, Split View with another app, and a real iPhone Duo.
- `NSUserActivity` annotations, snippet views, `continueInForeground` and `LongRunningIntent`.
