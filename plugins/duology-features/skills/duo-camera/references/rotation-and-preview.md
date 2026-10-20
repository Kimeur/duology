# Rotation and the preview

Keep the preview and captured photos upright on both displays, size the preview for each display, and keep controls clear of the fold and the cameras. Every block typechecks against the iOS 27.1 simulator SDK in Swift 5 and Swift 6 mode. None of it has run with a camera.

Apple's sources: [Supporting device rotation in your camera app](https://developer.apple.com/documentation/avfoundation/supporting-device-rotation-in-your-camera-app), [Tech Talk 111465](https://developer.apple.com/videos/play/tech-talks/111465/?time=426), [AVCaptureDevice.RotationCoordinator](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator), [dynamicAspectRatio](https://developer.apple.com/documentation/avfoundation/avcapturedevice/dynamicaspectratio).

## The preview view

```swift
import AVFoundation
import SwiftUI
import UIKit

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

/// The camera preview in SwiftUI. `onCreate` receives the UIView, which a
/// direction coordinator needs as its frame of reference.
struct CameraPreview: UIViewRepresentable {
    let source: PreviewSource
    var gravity: AVLayerVideoGravity = .resizeAspect
    var onCreate: (PreviewView) -> Void = { _ in }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = gravity
        source.connect(view.previewLayer)
        onCreate(view)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.previewLayer.videoGravity = gravity
    }
}
```

Keep the `CameraPreview` in one place in the view tree for every pose: an `ArrangementView`, one `Layout`, or `AnyLayout`. Then its UIView, and the coordinators that use it as their frame of reference, survive the fold (`duo-continuity`). If a fold does rebuild it, `onCreate` runs again with the new view, and `CameraModel.attachMain` makes new coordinators for it.

## Rotation on the capture actor

One rotation coordinator per camera and preview layer. The actor finds the preview layers through the session's connections, so a second layer (the subject view on the outer display) gets its own coordinator when you call `refreshRotation()`.

```swift
import AVFoundation

// requires: CaptureService (direction-and-mirroring.md)

extension CaptureService {
    /// Keeps every preview and the captured photos upright. On iPhone Duo the
    /// angles also change when the app moves to the other display (Tech Talk 111465).
    func trackRotation(of camera: AVCaptureDevice) {
        rotations = []
        rotationObservations = []
        let layers = session.connections.compactMap(\.videoPreviewLayer)
        for layer in layers {
            let coordinator = AVCaptureDevice.RotationCoordinator(device: camera, previewLayer: layer)
            let layerID = ObjectIdentifier(layer)
            rotations.append(coordinator)
            rotationObservations.append(coordinator.observe(
                \.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]
            ) { [weak self] _, change in
                guard let angle = change.newValue else { return }
                Task { await self?.rotatePreview(layerID, to: angle) }
            })
        }
        if let first = rotations.first {
            rotationObservations.append(first.observe(
                \.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]
            ) { [weak self] _, change in
                guard let angle = change.newValue else { return }
                Task { await self?.rotateCapture(to: angle) }
            })
        }
        // The coordinator now keeps photos upright, so the compensation for older
        // sensor orientations only costs time (Tech Talk 111465, at 8:37).
        if photoOutput.isCameraSensorOrientationCompensationSupported {
            photoOutput.isCameraSensorOrientationCompensationEnabled = false
        }
    }

    /// Call after a new preview layer connects, such as the subject view on the outer display.
    func refreshRotation() {
        if let camera = videoInput?.device { trackRotation(of: camera) }
    }

    private func rotatePreview(_ layerID: ObjectIdentifier, to angle: CGFloat) {
        let connection = session.connections.first { connection in
            connection.videoPreviewLayer.map(ObjectIdentifier.init) == layerID
        }
        guard let connection, connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    private func rotateCapture(to angle: CGFloat) {
        guard let connection = photoOutput.connection(with: .video),
              connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }
}
```

- The header says both angle properties are key-value observable and deliver updates on the main queue. The observer hops to the actor before it touches a connection.
- The capture angle depends on how the phone is held, not on a layer, so one coordinator's capture angle is enough.
- `AVCapturePhotoOutput.h` says the compensation rotates HEIC, JPEG and processed photos to match the sensor orientation of earlier hardware. The talk says it is on for every front camera on Duo. Turn it off only once the rotation coordinator handles orientation.
- iOS 27.0 adds `videoRotationAngleRelative(toDeviceOrientation:)`: the fixed angle for a given device orientation, whatever the phone does now. Use it when you need an angle for an orientation you choose, such as a saved preference.

## Sizing the preview on each display

| Display and camera | What Apple suggests | How |
|---|---|---|
| Inner display, rear camera | The full field of view leaves room around the preview. Offset the preview and group controls in the space left, or fill the display. | `videoGravity = .resizeAspect` plus your own placement, or `.resizeAspectFill` ([talk 111465](https://developer.apple.com/videos/play/tech-talks/111465/?time=430)) |
| Inner display, front camera | The square sensor can fill the display. Choose a landscape aspect ratio. | `setDynamicAspectRatio(_:completionHandler:)` ([talk 111465](https://developer.apple.com/videos/play/tech-talks/111465/?time=464)) |
| Outer display | Apple gives no special advice. Size from the view; the window is compact. | Same code |

```swift
import AVFoundation

// requires: CaptureService (direction-and-mirroring.md)

extension CaptureService {
    /// Asks the camera for a frame shape, when its format supports one.
    /// The front cameras' square sensors can fill the wide inner display this way.
    func setFrameAspect(_ ratio: AVCaptureDevice.AspectRatio) {
        guard let camera = videoInput?.device,
              camera.activeFormat.supportedDynamicAspectRatios.contains(ratio),
              (try? camera.lockForConfiguration()) != nil else { return }
        camera.setDynamicAspectRatio(ratio, completionHandler: nil)
        camera.unlockForConfiguration()
    }
}
```

- The SDK offers `.ratio1x1`, `.ratio4x3`, `.ratio3x4`, `.ratio16x9` and `.ratio9x16` (iOS 26). Setting an unsupported one throws an exception, so check `supportedDynamicAspectRatios` first, as above.
- *Unverified:* whether these names follow the sensor or the screen, so which one reads as "landscape" on the open phone. Try both on a device and keep the one that fills the display.
- Change it again when the phone closes: the outer display is narrow and tall in portrait.

## The preview and the reserved regions

The preview is content: it may run under the status bar and across a flat fold. Controls are not.

| Pose | Inner camera (`.occlusion`) | Fold (`.division`) |
|---|---|---|
| Closed | The outer camera instead: active, 37 × 37 pt at (400, 29) in a 466 × 678 pt window | none |
| Open, flat, held wide | Inactive until the camera runs: 58 × 37 pt at (677, 21) in a 951 × 669 pt window | inactive |
| Book | Same as open | active, 40 × 669 pt at (455, 0) |
| Tabletop | Inactive: 37 × 58 pt at (611, 677) in a 669 × 951 pt window, the right edge of the bottom region | active, 669 × 40 pt at (0, 455) |

*Measured* by `duo-postures` on the iPhone Duo simulator with no camera running ([measurements](https://github.com/Kimeur/duology/blob/main/plugins/duology-design/skills/duo-postures/references/measurements.md)). Apple says the inner camera's region turns active while it runs ([overview](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)); the simulator can't show that.

- A camera app on the inner display runs the inner camera often, so treat its region as active. Keep the shutter, zoom and mode controls clear of it.
- System containers already move around camera occlusions; Apple lists arrangement views among them (overview). For a custom control bar, read `reservedRegions(kind: .occlusion)` in a `GeometryReader` and move the bar out of any active frame (`duo-layout` has the code).
- Partly folded, keep every control out of the division frame. The preview can cross it.

## Sources

IDs point to [`reference/sources.md`](https://github.com/Kimeur/duology/blob/main/reference/sources.md): D1 (overview), D9 (rotation sample), V5 (camera talk), V11 (Center Stage front camera session).
