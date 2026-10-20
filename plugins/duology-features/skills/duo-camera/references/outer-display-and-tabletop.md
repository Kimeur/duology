# The outer display, flipped selfies and tabletop capture

The three camera moments only iPhone Duo has: showing the subject something on the outer display, taking a selfie with the rear camera, and capturing hands-free with the phone set on a table. Every block typechecks against the iOS 27.1 simulator SDK in Swift 5 and Swift 6 mode. None of it has run with a camera.

"Book", "tabletop" and "flipped" are Duology's words for Apple's descriptions: partly folded like a book, seated on a table like a laptop, open and turned around. None of them is an API.

## The camera model

One object per camera screen, held in `@State` on the screen's root, so a fold never builds a second one. It wires the direction watcher, one mirror per preview, the switch cover and the self-timer.

```swift
import AVKit
import Observation
import SwiftUI

// requires: CaptureService, DirectionWatcher, PreviewMirror (direction-and-mirroring.md)
// requires: PreviewView (rotation-and-preview.md)

#if !targetEnvironment(macCatalyst)
@available(iOS 27.1, *)
@MainActor @Observable
final class CameraModel {
    let capture = CaptureService()
    @ObservationIgnored let watcher: DirectionWatcher
    @ObservationIgnored let mainMirror = PreviewMirror()
    @ObservationIgnored let subjectMirror = PreviewMirror()   // the outer display's preview
    var isSwitching = false            // cover the preview while the new camera starts
    var secondsLeft: Int?              // self-timer, readable from across a table

    init() {
        watcher = DirectionWatcher(capture: capture)
        watcher.willSwitch = { [weak self] in self?.isSwitching = true }
        watcher.didSwitch = { [weak self] camera in
            guard let self else { return }
            mainMirror.camera = camera
            subjectMirror.camera = camera
            isSwitching = false
        }
    }

    /// The main preview, on whichever display the app is on.
    func attachMain(_ view: PreviewView) {
        watcher.watch(view)
        mainMirror.watch(view)
        Task { await capture.start() }
    }

    /// The subject's preview in the camera capture accessory, on the outer display.
    func attachSubject(_ view: PreviewView) {
        subjectMirror.watch(view)
        subjectMirror.camera = watcher.camera
        Task { await capture.refreshRotation() }   // the new layer needs its own rotation coordinator
    }

    func startTimer(seconds: Int = 5, then shutter: @escaping @MainActor () -> Void) {
        Task {
            for left in stride(from: seconds, to: 0, by: -1) {
                secondsLeft = left
                try? await Task.sleep(for: .seconds(1))
            }
            secondsLeft = nil
            shutter()
        }
    }
}
#endif
```

## The controls and the countdown

The same controls in every pose. The arrangement decides where they go; the views don't change.

```swift
import SwiftUI

// requires: CameraModel (this file)

#if !targetEnvironment(macCatalyst)
@available(iOS 27.1, *)
struct CaptureControls: View {
    let model: CameraModel

    var body: some View {
        HStack(spacing: 32) {
            Button("Self-Timer", systemImage: "timer") {
                model.startTimer { /* call your capture code on the capture actor */ }
            }
            Button("Take Photo", systemImage: "circle.inset.filled") { /* capture now */ }
                .font(.system(size: 56))
            Button("Switch Camera", systemImage: "arrow.triangle.2.circlepath.camera") {
                model.watcher.preference = model.watcher.preference == .frontFirst ? .rearFirst : .frontFirst
            }
        }
        .labelStyle(.iconOnly)
        .font(.title)
        .foregroundStyle(.white)
        .padding()
        .frame(maxHeight: .infinity, alignment: .bottom)     // floating over the preview: bottom edge
    }
}
#endif

/// The countdown sits on the preview, so in tabletop it shows in the top region.
struct TimerBadge: View {
    let secondsLeft: Int?

    var body: some View {
        if let secondsLeft {
            Text("\(secondsLeft)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(radius: 8)
                .accessibilityLabel("\(secondsLeft) seconds")
        }
    }
}
```

- "Switch Camera" changes the preference, not the camera: the watcher picks a forward-facing camera of that kind if one exists. Open on the inner display only the inner camera faces forward, so it does nothing there. Hide it when the direction map has a single forward camera, if that suits your app.
- Each button has a title for VoiceOver and Voice Control, even with `.iconOnly`.

## Subject preview on the outer display

Apple's conditions for the camera capture accessory: the phone fully open, your app in the foreground and full screen on the inner display, a capture session running (the overview names the rear camera), and the view that registered it on screen ([guide](https://developer.apple.com/documentation/avfoundation/registering-a-camera-capture-accessory-on-iphone-duo), [talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/?time=314)). `duo-scenes` explains availability, the on/off switch and the UIKit registration; this page covers the camera side.

```swift
import SwiftUI

// requires: CameraModel, TimerBadge (this file), CameraPreview (rotation-and-preview.md)

#if !targetEnvironment(macCatalyst)
/// What the person in front of the rear camera sees on the outer display:
/// their own picture, mirrored by its own coordinator, and the countdown.
@available(iOS 27.1, *)
struct SubjectPreview: View {
    let model: CameraModel

    var body: some View {
        CameraPreview(source: model.capture.previewSource, gravity: .resizeAspectFill) {
            model.attachSubject($0)
        }
        .overlay { TimerBadge(secondsLeft: model.secondsLeft) }
        .ignoresSafeArea()
    }
}
#endif
```

What makes it right on Duo:

- **Its own direction coordinator.** From the outer display's view the rear cameras face forward; from the inner display's view they face backward. Apple's talk says to make a coordinator for each view ([talk 111465](https://developer.apple.com/videos/play/tech-talks/111465/?time=299)). `PreviewMirror` then mirrors the subject's preview and leaves the photographer's alone.
- **Its own rotation coordinator.** It is a second layer. `attachSubject` asks the actor to track it.
- **No essential control.** The system can withdraw it at any time. A tap to focus is the most Apple suggests (guide).
- **New views each time.** `duo-scenes` measured that closing and reopening the phone builds a new accessory scene and new views. Keep everything in `CameraModel`, as here.
- *Unverified:* a second `AVCaptureVideoPreviewLayer` on one session, on a device. The `deferredStartEnabled` documentation in `AVCaptureVideoPreviewLayer.h` (iOS 26) talks about apps with several preview layers, which suggests it works. If it doesn't, show a framing guide or the countdown alone.
- *Measured, no capture session* (the simulator shows accessories without one): available closed-then-opened and in book at 128°; tabletop not measured. Details in [testing.md](testing.md#the-accessory-in-each-pose).

## Flipped: a selfie with the rear camera

Open and turned around, a camera app can move to the outer display, and both the rear cameras and the outer front camera face forward ([talk 111465](https://developer.apple.com/videos/play/tech-talks/111465/?time=277)).

- The watcher's default (`frontFirst`) keeps the outer front camera. Offer "Switch Camera" so people can choose the rear camera instead.
- `PreviewMirror` mirrors the rear camera here, so the preview looks like a mirror.
- The layout is your compact layout; nothing new is needed ([duo-postures](https://github.com/Kimeur/duology/blob/main/plugins/duology-design/skills/duo-postures/SKILL.md)).
- Device Hub has no flip control, and the simulator has no camera. Test on a device.

## Tabletop: hands-free capture

Apple singles out the phone set on a table as good for hands-free use: media at the top, controls you tap on the stable base, and the same controls and hierarchy as every other pose ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=283), [talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=263)). `CaptureScreen` in SKILL.md does this with an overlay arrangement.

What the arrangement did, *measured* on the iPhone Duo simulator on 20 Oct 2026 with a playing video as the secondary view and a panel as the primary (a camera preview can't run there):

| Pose | Window | Primary (controls) | Secondary (preview) |
|---|---|---|---|
| Closed | 466 × 678 pt | Over the secondary, whole window | Whole window |
| Open, flat | 951 × 669 pt | Over the secondary, whole window | Whole window |
| Book | 951 × 669 pt | Trailing region, 455 × 669 pt at x 495 | Leading region |
| Tabletop | 669 × 951 pt | Bottom region, 669 × 455 pt at y 495 | Top region |

- The secondary view was built once and never rebuilt through every pose, and the video kept playing through book, tabletop and closing. A camera preview in its place keeps its UIView, so its direction coordinator keeps working (*derived*).
- The primary floats over the whole window when flat. That is why `CaptureControls` aligns itself to the bottom edge.

Where the cameras are when the phone sits on a table:

- *Derived from the simulator:* after Partially Open and Rotate Right in Device Hub, the inner camera's region sat on the right edge of the bottom region. Set on a table, that half lies flat, so the inner camera would point up. Turned the other way, it would sit in the upright half. Ask the coordinator what faces forward; never assume which half is which. *Unverified* on a device.
- The rear cameras sit on the back of one half (the [accessory guide's](https://developer.apple.com/documentation/avfoundation/registering-a-camera-capture-accessory-on-iphone-duo) drawing shows the rear cameras on one panel and the outer display on the other). If the upright half carries them, they point away from the person, like a camera on a tripod. *Unverified:* which half that is in each tabletop orientation.
- Apple's conditions for the camera capture accessory say fully open, so plan for it to be gone in tabletop. The simulator offered it in book (*measured*, no capture session); tabletop is unmeasured. Show the countdown in the main UI, as `TimerBadge` does.

Test the layout in Device Hub with the camera replaced by a placeholder ([testing.md](testing.md#a-placeholder-for-the-preview)). Test the cameras on a device.

## Sources

IDs point to [`reference/sources.md`](https://github.com/Kimeur/duology/blob/main/reference/sources.md): D1 (overview), D8 (accessory guide), V3 (layouts talk), V4 (scenes talk), V5 (camera talk), V6 (design talk).
