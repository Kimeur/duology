# __APP_NAME__

A camera studio for iPhone Duo. Take photos and videos with the rear camera, with a self-timer. While the phone is open, the person you film sees themselves on the outer display: their own picture, mirrored, a framing guide, and the countdown or the recording time. Fold it like a book and the controls move to the right page; set it on a table half folded and the preview sits above the fold with the controls below, for hands-free shots. Photos and videos stay in the app's gallery until you share them.

The simulator has no camera. There the studio uses a stand-in: a moving test card that the shutter photographs and the recorder films, so every pose, the timer, recording and the gallery can be tried without a device.

## Run it

```bash
Tools/run-model-tests.sh      # layouts, timer, gallery index, stand-in frames and privacy checks, on your Mac
open __APP_NAME__.xcodeproj   # choose the iPhone Duo simulator, then Run
Tools/run-ui-tests.sh         # the UI tests on the iPhone Duo simulator (stand-in camera)
```

You need Xcode 27.1 or later. The scripts use `/Applications/Xcode-27.1.app` unless you set `DEVELOPER_DIR`.

## What's where

| Folder | What it holds |
|---|---|
| `__APP_NAME__/Model/` | The rules: the studio layout from the size and the fold, the self-timer, the recording clock, the gallery's index, the stand-in camera's picture, camera access messages. Foundation, CoreGraphics and ImageIO only. |
| `__APP_NAME__/Capture/` | `CaptureService` (the real camera: session, photos, movies, rotation), the preview views, and the stand-in recorder. |
| `__APP_NAME__/Studio/` | The studio screen, its controls, the subject view on the outer display, the gallery. |
| `__APP_NAME__/Shared/` | The fold reader, the studio's layout, test markers. |
| `__APP_NAME__/App/` | The app entry, the root view, the store and the launch switches for tests. |
| `__APP_NAME__/PrivacyInfo.xcprivacy` | No tracking, no data collected, no required-reason API. |
| `__APP_NAME__UITests/` | UI tests that drive the real app with the stand-in camera. |
| `__APP_NAME__/Assets.xcassets/` | The accent colour and a placeholder app icon: one 1024 × 1024 image, from which Xcode makes the other sizes. Replace the icon with your own before you ship. |
| `Tools/` | The model test program and both test scripts. |

## Before you ship

- Try every capture path on a real iPhone Duo: none of it has run with a camera yet. The list is in the recipe's `references/device-checks.md`.
- Replace the placeholder app icon in `Assets.xcassets/AppIcon.appiconset` with your own 1024 × 1024 image, without transparency.
- Read the camera, microphone and photo library usage strings in the target's Info settings, and make them yours.
- Keep "They stay on this device" true. If you add uploads or sync, change the usage strings, the privacy manifest and your App Store Connect privacy answers together. `Tools/run-model-tests.sh` fails if networking appears in the app's sources.

## Launch switches

Debug builds only. Add them in the scheme (Product > Scheme > Edit Scheme > Arguments) or in UI tests.

| Switch | Effect |
|---|---|
| `-standIn` | Use the stand-in camera even on a device with a camera. |
| `-mode NAME` | Start in `photo` or `video` mode. |
| `-timer SECONDS` | Start with the self-timer at `3` or `10` seconds. |
| `-shutter` | Press the shutter once at launch; with `-timer`, start the countdown. For screenshots. |
| `-resetState` | Delete every photo and video in the gallery. |
| `-uiTesting` | Animations off, test markers on. |

## Testing notes

- Poses change only in Device Hub (Closed, Partially Open, Open). Check each by hand: closed, the preview with the controls along the bottom; open and flat, the controls along the trailing edge, off the fold; folded like a book, the preview on the left page and the controls on the right; Partially Open then Rotate Right (tabletop), the preview above the fold and the controls below it.
- Open the phone and start the self-timer (or launch with `-timer 10 -shutter`): the outer display shows the subject view with the countdown. Take its screenshot with `xcrun simctl io <UDID> screenshot --display=primary`; with the phone open it comes out on its side, so turn it a quarter turn counterclockwise.
- Start a countdown or a recording, then close, open and fold the phone: it carries on.
