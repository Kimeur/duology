# The cameras on iPhone Duo

What each camera is, how to reach it, and how to read what it can do at run time. Every Swift block in this skill typechecks against the iOS 27.1 simulator SDK in Swift 5 and Swift 6 mode, with iOS 27.1 and iOS 26 deployment targets. None of it has run with a camera: the simulator has none.

Apple's sources: [Choosing a camera by the direction it faces](https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces), [Tech Talk 111465](https://developer.apple.com/videos/play/tech-talks/111465/), the [spec page](https://www.apple.com/iphone-duo/specs/), and `AVCaptureDevice.h` in the iOS 27.1 SDK.

## What each camera offers

| | Virtual front camera | Outer front | Inner front | Rear |
|---|---|---|---|---|
| Device type | `.builtInWideAngleCamera` or `.builtInUltraWideCamera`, at `.front` | `.builtInOuterUltraWideCamera` (iOS 27.1) | `.builtInInnerUltraWideCamera` (iOS 27.1) | Your usual rear types |
| `position` | `.front` | `.front` | `.front` | `.back` |
| Hardware | None of its own; it streams from one of the two front cameras | 12MP Center Stage camera, square sensor, f/2.2 (spec page) | Under-display FaceTime camera, square sensor, f/1.8 (spec page) | 48MP Fusion Main and 48MP Fusion Ultra Wide (spec page) |
| Video | Up to 1080p at 60 fps, the features both front cameras share (talk) | Up to 4K and 120 fps (talk); 4K up to 60 fps and 120 fps slo-mo at 1080p (spec page) | 1080p up to 60 fps (talk) | As on other iPhones |
| Depth | No (talk) | Through the physical camera (talk) | Through the physical camera (talk) | As on other iPhones |
| Who switches when the phone opens | The system | Your app | Your app | Your app |

- The talk and the spec page give different frame rates for the outer camera. Don't pick one. Read the formats on the device with `videoLimits` below.
- The talk says depth needs the individual cameras. It doesn't say which formats carry it. Check `supportedDepthDataFormats`.
- `AVCaptureDevice.h` marks both new types `API_UNAVAILABLE(macCatalyst)` and says they can only be discovered with a discovery session.

## Reach each camera

```swift
import AVFoundation

/// The two physical front cameras. `AVCaptureDevice.h` says these types can only be
/// discovered with a discovery session, so don't look them up with `AVCaptureDevice.default`.
@available(iOS 27.1, *)
@available(macCatalyst, unavailable)
func duoFrontCameras() -> (outer: AVCaptureDevice?, inner: AVCaptureDevice?) {
    let devices = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInOuterUltraWideCamera, .builtInInnerUltraWideCamera],
        mediaType: .video, position: .unspecified
    ).devices
    return (devices.first { $0.deviceType == .builtInOuterUltraWideCamera },
            devices.first { $0.deviceType == .builtInInnerUltraWideCamera })
}

/// The physical camera behind a virtual one. `nil` until the session runs.
func streamingCamera(of camera: AVCaptureDevice) -> AVCaptureDevice? {
    camera.isVirtualDevice ? camera.activePrimaryConstituent : camera
}

extension AVCaptureDevice {
    /// The largest frame and the fastest rate this camera offers, read at run time.
    var videoLimits: (width: Int32, height: Int32, fps: Float64) {
        var best: (width: Int32, height: Int32, fps: Float64) = (0, 0, 0)
        for format in formats {
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            if Int(size.width) * Int(size.height) > Int(best.width) * Int(best.height) {
                best.width = size.width
                best.height = size.height
            }
            for range in format.videoSupportedFrameRateRanges {
                best.fps = max(best.fps, range.maxFrameRate)
            }
        }
        return best
    }

    /// Whether any format of this camera delivers depth.
    var offersDepth: Bool {
        formats.contains { !$0.supportedDepthDataFormats.isEmpty }
    }
}
```

- `streamingCamera(of:)` on the virtual front camera tells you whether the inner or the outer camera streams. Use it for analytics or a label, not to decide what to do: the system can switch at any time.
- Pick formats from what the camera reports. A format list from another iPhone won't match.

## When the virtual front camera is enough

It is the right default for most apps ([guide](https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces)):

- It needs no new code and no iOS 27.1 API.
- It switches when the phone opens and closes, so a video call keeps going through a fold.
- The system decides which camera streams. You can't keep the outer camera while the phone is open.

Move to the physical cameras when:

- you need 4K or more than 60 fps from the outer camera, or depth;
- you want the rear camera for a selfie when the phone is turned around;
- you want to stay on one camera while the phone opens or closes. Apple's talk gives the case of an app on the inner display streaming from the outer front camera, which then faces away from the person holding the phone ([talk 111465](https://developer.apple.com/videos/play/tech-talks/111465/?time=199)).

## Two cameras at once

Apple's guide says to reconfigure one video input when the direction changes, not to run both cameras in a multi-camera session: it costs less and covers what most apps need. If your app truly records from two cameras at once, check `AVCaptureMultiCamSession.isMultiCamSupported` on the device first; we found nothing in Apple's iPhone Duo material about which pairs of cameras can run together (unverified).

## Sources

IDs point to [`reference/sources.md`](https://github.com/Kimeur/duology/blob/main/reference/sources.md): A2 (spec page), D7 (camera direction guide), V5 (camera talk), V11 (Center Stage front camera session).
