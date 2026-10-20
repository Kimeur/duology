# Testing media on iPhone Duo

What we measured on the simulator, how we measured it, and what only a device can show.

## How we measured

A probe app built with `swiftc` for the iOS 27.1 simulator SDK, installed on the shared iPhone Duo simulator (iOS 27.1, Xcode 27.1) on 20 October 2026. It wrote a 12-second test movie on the device with `AVAssetWriter` (no download), looped it with `AVQueuePlayer` and `AVPlayerLooper` from a model, and logged once a second: the playback time, `timeControlStatus`, the window size, the hinge status, the arrangement's z-index and the frame of the primary view. `duo-pose` from [duo-pose-matrix](https://github.com/Kimeur/duology/blob/main/plugins/duology-ship/skills/duo-pose-matrix/SKILL.md) pressed Device Hub's Open, Partially Open, Rotate Right and Closed buttons, and `simctl io` saved a screenshot of the inner display in each pose.

Device Hub's Partially Open settled at 127° (hinge angle logged by `onHingeChange`), as `duo-postures` measured.

## The overlay arrangement in each pose

`ArrangementView` with `.overlay`. Primary: a panel. Secondary: the playing video in an `AVPlayerLayer`.

| Pose | Window | Primary frame | `overlayArrangementZIndex` (read one view inside the primary) |
|---|---|---|---|
| Closed | 466 × 678 pt | 0, 0, 466 × 678 | 1 |
| Open, flat | 951 × 669 pt | 0, 0, 951 × 669 | 1 |
| Book | 951 × 669 pt | 495, 0, 455 × 669 | 0 |
| Tabletop | 669 × 951 pt | 0, 495, 669 × 455 | 0 |

- The secondary's UIView was made once for the whole run.
- Playback continued through book, tabletop and closing: about 3 s of playback per 3 s of clock, `timeControlStatus` playing (raw value 2) throughout.
- In book and tabletop the 40 pt between 455 and 495 is the fold's division frame (`duo-postures` measured the same frame). The arrangement kept both views out of it.
- Closing from tabletop, the z-index read 1, 0, 1 within 0.06 s as the window went from 951 × 669 to 466 × 678 pt.

## The system player in each pose

Not measured. Our run of `AVPlayerViewController` through book and tabletop was cut short: the shared simulator was busy with other UI tests. Until someone measures it, assume the system player keeps its controls over the video, and use your own controls when you want them below the fold. To measure it, play a video in `AVPlayerViewController`, pause it so the controls stay up, and screenshot the inner display in each pose.

## Picture in Picture

`AVPictureInPictureController.isPictureInPictureSupported()` returned `false` on the iPhone Duo simulator. Picture in Picture can't be tested there.

## On a real iPhone Duo

Nothing below has been checked yet (`device: no`).

| Check | Expect |
|---|---|
| Play, then close, open, fold to book and to tabletop | Time keeps counting, no flash, no restart |
| Tabletop with the overlay arrangement | Video in the top region, the same controls below the fold |
| Inline video, then go home | Picture in Picture starts when `canStartPictureInPictureAutomaticallyFromInline` is set |
| Pin a Picture in Picture video on top, then fold | Your app gets shorter, then about half the screen; every control still works |
| Lock Screen and Control Center | Title and play and pause work from the model's Now Playing session |
| Headphones out, then a call | Playback pauses; after the call it resumes only when `resumptionRecommendationNotification` says `.shouldResume` |
| Split View on each side | Controls usable at half width |
| Closed, video playing | The outer camera's corner covers video only, no control |
