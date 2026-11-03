# Architecture of the camera studio recipe

How the app made by `recipe-camera-studio` is put together, who owns what, and what we ran. *Measured* means on the iPhone Duo simulator (iOS 27.1, Xcode 27.1) on 2 November 2026.

## The layers

| Layer | Files | Rules |
|---|---|---|
| Model | `Model/*.swift` | Foundation, CoreGraphics and ImageIO only. Every type `nonisolated` and `Sendable`, so the Mac tests build it with the app's settings and use it off the main actor. |
| Capture | `Capture/CaptureService.swift`, `Capture/StandIn.swift`, `Capture/CameraPreview.swift` | AVFoundation lives here. `CaptureService` and `StandInRecorder` are actors; the preview views are on the main actor. |
| Views | `Studio/*.swift`, `Shared/*.swift` | Read the store; never own capture state, never pick a layout from the device or the pose. |
| App | `App/*.swift` | `RootView` owns the one `StudioStore`; `LaunchOptions` reads the switches in Debug builds only. |

## Who owns what

| State | Owner | Survives |
|---|---|---|
| The camera session, its inputs and outputs | `CaptureService` (an actor), held by `StudioStore` | folds; the preview layers keep their views |
| Mode, side, timer setting, the countdown and its task, the recording | `StudioStore` | folds, leaving the gallery sheet |
| The gallery | `CaptureLibrary` in `StudioStore`, saved to `Documents/Captures/Captures.json` after every change; files beside it | folds, quitting, relaunch |
| The subject view's switch (`showsSubjectView`) and availability (`subjectViewAvailable`) | `StudioStore`; the system sets availability through `onAvailabilityChange` | folds; the accessory scene itself is rebuilt each time the phone opens |
| The fold and the size | `@State` in `StudioScreen` | read again after every change |

`RootView` never changes identity, so neither does the store. A fold resizes the window; the preview is the first subview of one `StudioSplit` in every pose, so SwiftUI keeps the same `PreviewView`, its `AVCaptureVideoPreviewLayer` and its rotation coordinator.

## One photo, start to finish

1. The shutter calls `StudioStore.shutter()`. With the timer on, it starts a `Countdown` and a task that ticks once a second; the countdown shows on the preview and on the outer display. A second tap cancels it.
2. At zero, or at once with the timer off, `takePhoto()` asks `CaptureService.capturePhoto()` (real camera) or renders `StandInFrame` (stand-in) for JPEG data.
3. `capturePhoto()` makes `AVCapturePhotoSettings` with JPEG when the output offers it, keeps a `PhotoDelegate` until the photo arrives (the output holds its delegate weakly), and returns `fileDataRepresentation()` through a continuation. If no photo comes, the capture's last callback (`didFinishCaptureFor:`) answers with an error, so the task never waits forever.
4. The store writes the file to `Documents/Captures/<id>.jpg`, adds a `Capture` to the index with the app's own date, and saves the index.

## One video, start to finish

1. In video mode the shutter starts recording (after the timer, if set). `CaptureService.configure` has added the movie output and, when the person allowed it, the microphone; `startRecording(to:)` hands the output a `MovieDelegate`.
2. The stand-in instead starts `StandInRecorder`, which appends a rendered frame 15 times a second through an `AVAssetWriterInputPixelBufferAdaptor`.
3. The second tap stops. `stopRecording()` always asks the output to stop (`isRecording` turns true only once samples are written, so a Stop right after Start would otherwise leave it running), then waits for the delegate. A recording can end on its own (a full disk, an interruption), so the delegate keeps the first outcome until someone asks, and gives up after 10 seconds without one, so the shutter never stays stuck. A movie that stopped with `AVErrorRecordingSuccessfullyFinishedKey` set is kept. While a recording starts the shutter is busy, so a second tap can't start a second one.
4. `Poster.jpeg(fromMovieAt:)` grabs the first frame with `AVAssetImageGenerator` for the grid, and the store adds the capture with its length.

## The layout in each pose

`StudioLayout(size:fold:controlsThickness:)` has three modes:

| Mode | When | Preview | Controls |
|---|---|---|---|
| `foldLeftRight` | an active fold runs top to bottom across the middle half (book) | left of the fold's frame | right of it, a column |
| `foldTopBottom` | an active fold runs side to side across the middle half (tabletop) | above the fold's frame | below it, a row |
| `floating` | anything else: closed, open and flat, Split View | the whole screen | over the preview: a 132 pt bar along the bottom when taller than wide, a 132 pt column along the trailing edge when wider; never more than half the short side |

Flat and folded differ on purpose. Flat, a camera wants the whole screen, and the fold can't be felt; folded, the halves are at an angle and the controls get one of their own. That is what Apple's `ArrangementView` with the overlay style did when `duo-camera` measured it, written as geometry so it runs below iOS 27.1 and is tested on the Mac. Floating controls sit at the edge, away from where the fold runs, in every size we measured; the Mac tests and `testStudioLayoutInThisPose` check it.

The fold is read with `.division` and `.includeInactive` on the `StudioSplit` itself. A fold that doesn't cross the middle half (a window beside it in Split View) is ignored.

## The subject view

`SubjectView` is the content of a `CameraCaptureAccessory`, registered with `sceneAccessory` on the studio screen behind `#available(iOS 27.1, *)` and `#if !targetEnvironment(macCatalyst)`, as `duo-scenes` explains. It shows:

- with the real rear camera, a second `CameraPreview` on the same session, `.resizeAspectFill`, which calls `CaptureService.attachSubjectPreview(_:mirrored: true)` so it gets its own rotation coordinator and is mirrored;
- with the stand-in, `StandInPreview(mirrored: true)`;
- with the front camera, black: the subject isn't in front of it;
- over it, the thirds and either the countdown (220 pt), the recording time, or "Look here".

It holds no state, so the new scene the system builds each time the phone opens shows the same countdown at once.

## Mirroring and rotation

- The photographer's preview on the inner display uses the connection's automatic mirroring: rear not mirrored, front mirrored.
- The subject's preview is mirrored for the rear camera, and set again after every configuration: a new input (a mode or camera switch) makes a new preview connection, which starts with automatic mirroring. From the outer display the rear camera faces the subject, and Apple's direction guide says a camera facing the viewer should look like a mirror (`duo-camera`). This is *derived*: the app doesn't run an `AVCaptureDeviceDirectionCoordinator` for it. If a device shows otherwise, use `duo-camera`'s `PreviewMirror` on the subject's view.
- `trackRotation(of:)` makes one `AVCaptureDevice.RotationCoordinator` per preview layer and applies the capture angle to the photo and movie connections. It runs after each configuration and each time a preview layer connects.

## The UI tests

All tests run the stand-in (`-standIn`) and read markers, never positions, so the same test passes in every pose. `testStudioLayoutInThisPose` attaches the frames and a screenshot of each display with a 10-second countdown running.

What the first runs found, now fixed:

- The stand-in preview filled the whole screen instead of 4:3, so its last bar hid under the floating controls. `StandInFrame.fitted(_:in:)` now letterboxes it like `.resizeAspect`.
- The gallery's toolbar button and its confirmation button were both called "Delete", and the test tapped the toolbar one again. The confirmation now says "Delete Photo" or "Delete Video".
- One pose run waited 70 minutes on "The test runner hung before establishing connection", an Xcode runner problem; the same test passed on the next run.

## What we ran

| Run | Result |
|---|---|
| `Tools/run-model-tests.sh`, template and a generated project | 82 checks, 0 failed |
| `xcodebuild build`, generated project, iPhone Duo simulator | succeeded, no warnings from the app's code, the capture actor included |
| `Tools/run-ui-tests.sh`, closed | all 8 passed in a freshly generated project, in two runs (113 s and about 270 s) |
| `testStudioLayoutInThisPose` in open, book, tabletop and closed (poses set with `duo-pose`) | passed in each; frames in SKILL.md section 3; the subject view showed on the outer display open, in book and in tabletop |
| A stand-in recording, read back with AVFoundation on the Mac | one H.264 track, 640 × 480, 15 frames a second, 6.47 s, the same length as the index; poster 640 × 480, upright |
| `duo-lint --strict` on a generated project | 0 findings (23 files) |

## Not yet verified

- Everything with a real camera: section 5 of SKILL.md and [device-checks.md](device-checks.md).
- Playback in the gallery, the share sheet's Save Image, VoiceOver, right-to-left languages, the closed phone held sideways, the open phone held tall, Split View.
