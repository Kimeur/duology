# Testing camera code for iPhone Duo

The iPhone Duo simulator has no camera. Use it for layout; use a device for capture. This page says what we measured in the simulator, how to check layout without a camera, and what to check on a device.

## What the simulator did

*Measured* on the shared iPhone Duo simulator (iOS 27.1, Xcode 27.1) on 20 October 2026, with a probe app built for the iOS 27.1 SDK:

| Check | Result |
|---|---|
| `DiscoverySession` for `.builtInWideAngleCamera` and `.builtInUltraWideCamera` at `.front` (the virtual front camera) | No devices |
| `DiscoverySession` for `.builtInOuterUltraWideCamera` and `.builtInInnerUltraWideCamera` | No devices |
| `DiscoverySession` for every type above plus `.builtInDualWideCamera` and `.builtInTripleCamera`; `AVCaptureDevice.default(for: .video)` | 0 devices; `nil` |
| `AVCaptureDeviceDirectionCoordinator` on a view in the window | `deviceDirections` empty at creation. The handler never ran: not in 30 s on the closed phone, not in 2 minutes during which the window resized. |
| `AVCaptureDevice.authorizationStatus(for: .video)` | `.notDetermined` (raw value 0) |

So in the simulator:

- every camera lookup returns nothing. Code that force-unwraps a camera crashes there before it ever reaches a device;
- the direction watcher never switches, so `CameraModel.isSwitching` stays `false` and the preview stays empty;
- the camera capture accessory shows without a capture session, a known issue in the [Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes).

### The accessory in each pose

`CameraCaptureAccessory` on a full-screen view, with `onAvailabilityChange` logged. No capture session ran: the simulator shows accessories without one.

| Pose at the time | Availability | Content |
|---|---|---|
| Closed, at launch | `false` | none |
| Closed, then Open | `true` as the window moved to the inner display, 0.1 s before the hinge reported 180° | appeared on the outer display |
| Partially Open at 128°, held wide (book), at launch | `true` | appeared at once |
| Tabletop | not measured | |

- Book is the surprise: Apple's conditions say fully open, yet the simulator offered the accessory partly open. With no capture session the simulator already ignores one condition, so this may not hold on a device (unverified).
- Tabletop wasn't measured: the shared simulator was busy with other UI tests.
- So don't depend on the accessory in any pose. Show the countdown in the main UI too, as `TimerBadge` on the preview does.

## A placeholder for the preview

Show something in the preview's place when there is no camera, so you can check every pose in Device Hub: the controls in the bottom region in tabletop, the trailing region in book, nothing in the fold, the countdown readable.

```swift
import SwiftUI

/// The simulator has no camera. Draw a stand-in where the preview goes, so the
/// layout can be checked in every pose. On a device with a camera, show the preview.
struct PreviewOrPlaceholder<Preview: View>: View {
    let hasCamera: Bool
    @ViewBuilder var preview: Preview

    var body: some View {
        if hasCamera {
            preview
        } else {
            LinearGradient(colors: [.teal, .indigo], startPoint: .top, endPoint: .bottom)
                .overlay {
                    Label("No camera", systemImage: "camera")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Camera preview placeholder")
        }
    }
}
```

Work out `hasCamera` once, for example `usualFrontCamera() != nil` (SKILL.md section 2), and keep it in the model. A value that never changes doesn't swap view identity on a fold.

Change poses in Device Hub, by hand or with `duo-pose` from [duo-pose-matrix](https://github.com/Kimeur/duology/blob/main/plugins/duology-ship/skills/duo-pose-matrix/SKILL.md) if the user has given Accessibility permission. Screenshot each display with `xcrun simctl io <UDID> screenshot --display=primary` (outer) and `--display=primary-1` (inner).

## On a real iPhone Duo

Nothing below has been checked yet (`device: no`). Run each line and note what happened.

| Check | Expect |
|---|---|
| Video call on the virtual front camera, then open and close the phone | The call keeps streaming. `activePrimaryConstituent` changes between the outer and inner camera. The session doesn't stop. |
| Log `videoLimits` and `offersDepth` for each camera | Compare with the talk (outer: 4K, 120 fps; inner: 1080p, 60 fps; virtual: 1080p, 60 fps, no depth) and the spec page |
| Physical cameras, open and close | The handler fires, the preview is covered for a moment, the new camera streams, mirroring is right |
| Open, turned around, "Switch Camera" | The rear camera streams and its preview is mirrored |
| Rotate in each pose, then take a photo | Preview and photo upright on both displays |
| Fully open, rear camera running | The subject view appears on the outer display, mirrored, with the countdown |
| Stop capture, close the phone, enter Split View, push a screen with its own accessory | The subject view goes away each time |
| Partially open (book, then tabletop) with the subject view showing | Note whether it stays |
| Tabletop, each way round | Preview on top, controls below. Note which cameras face forward. |
| Split View with another app | The interruption message shows; capture comes back at full screen |
| A front camera on the inner display | The shutter stays clear of the camera's area while it runs |
| `setFrameAspect` with `.ratio16x9`, then `.ratio9x16`, open | Note which one fills the wide display |
