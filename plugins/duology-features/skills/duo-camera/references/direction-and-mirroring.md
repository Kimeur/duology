# Direction, switching and mirroring

How to keep capture on a camera that faces the person, switch without a flash of the wrong picture, and mirror by direction. The code splits the work the way Apple's guide asks: the direction coordinator and the views on the main actor, every AVFoundation configuration call on one actor that owns the session.

Apple's sources: [Choosing a camera by the direction it faces](https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces), [Tech Talk 111465](https://developer.apple.com/videos/play/tech-talks/111465/?time=173), `AVKit/AVCaptureDeviceDirectionCoordinator.h` and `AVFoundation/AVCaptureSession.h` in the iOS 27.1 SDK.

Every block typechecks against the iOS 27.1 simulator SDK in Swift 5 and Swift 6 mode. None of it has run with a camera.

## The capture actor

```swift
import AVFoundation

/// Lets a preview layer on the main actor hold the session. AVCaptureSession
/// isn't Sendable, so this box is unchecked: only `connect(_:)` touches it,
/// and all configuration stays on the actor.
struct PreviewSource: @unchecked Sendable {
    fileprivate let session: AVCaptureSession

    @MainActor func connect(_ layer: AVCaptureVideoPreviewLayer) {
        layer.session = session
    }
}

/// Owns the capture session. Every AVFoundation call that configures capture runs here.
actor CaptureService {
    let session: AVCaptureSession          // configure it only on this actor
    nonisolated let previewSource: PreviewSource
    let photoOutput = AVCapturePhotoOutput()
    var videoInput: AVCaptureDeviceInput?
    var rotations: [AVCaptureDevice.RotationCoordinator] = []
    var rotationObservations: [NSKeyValueObservation] = []

    init() {
        let session = AVCaptureSession()
        self.session = session
        previewSource = PreviewSource(session: session)
    }

    /// Swaps the video input for the camera with this ID. Returns false when the
    /// camera is gone or doesn't fit, and keeps the old input.
    @discardableResult
    func useCamera(withID uniqueID: String) -> Bool {
        // A descriptor names a camera; it doesn't reserve it. It may be gone by now.
        guard let camera = AVCaptureDevice(uniqueID: uniqueID),
              let input = try? AVCaptureDeviceInput(device: camera) else { return false }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        let previous = videoInput
        if let previous { session.removeInput(previous) }
        guard session.canAddInput(input) else {
            if let previous { session.addInput(previous) }
            return false
        }
        session.addInput(input)
        videoInput = input
        if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        trackRotation(of: camera)   // a rotation coordinator serves one camera
        return true
    }

    /// The front camera every app already asks for. On iPhone Duo it is the
    /// virtual front camera, which follows the app between the displays.
    @discardableResult
    func useFrontCamera() -> Bool {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera],
            mediaType: .video, position: .front)
        guard let camera = discovery.devices.first else { return false }   // the simulator ends here
        return useCamera(withID: camera.uniqueID)
    }

    func start() {
        if !session.isRunning { session.startRunning() }   // blocks: never on the main actor
    }

    func stop() {
        if session.isRunning { session.stopRunning() }
    }
}
```

`trackRotation(of:)` is in [rotation-and-preview.md](rotation-and-preview.md#rotation-on-the-capture-actor).

## The direction watcher

The full version of `FrontCameraFollower` in SKILL.md. It adds a preference for flipped selfies and two hooks: one to cover the preview before a switch, one to fix mirroring and uncover it after.

```swift
import AVKit
import UIKit

#if !targetEnvironment(macCatalyst)   // the outer and inner camera types don't exist there
/// Keeps capture on a camera that faces the person looking at one preview view.
@available(iOS 27.1, *)
@MainActor
final class DirectionWatcher {
    enum Preference { case frontFirst, rearFirst }

    /// The physical cameras that can face the person. The coordinator skips the
    /// virtual front camera, so list both physical front cameras instead.
    static let cameraTypes: [AVCaptureDevice.DeviceType] = [
        .builtInOuterUltraWideCamera, .builtInInnerUltraWideCamera, .builtInDualWideCamera,
    ]

    private let capture: CaptureService
    private var coordinator: AVCaptureDeviceDirectionCoordinator?
    private(set) var directions: AVCaptureDeviceDirectionMap?
    private(set) var camera: AVCaptureDeviceDescriptor?
    /// Runs before a switch (cover the preview) and after it (mirror, uncover).
    var willSwitch: () -> Void = {}
    var didSwitch: (AVCaptureDeviceDescriptor) -> Void = { _ in }

    /// Turned around, both a rear camera and the outer front camera face the person.
    var preference = Preference.frontFirst {
        didSet { if let directions { camera = nil; update(directions) } }
    }

    init(capture: CaptureService) { self.capture = capture }

    /// Call once the preview view exists; keep the watcher while it is on screen.
    func watch(_ previewView: UIView) {
        coordinator = AVCaptureDeviceDirectionCoordinator(
            view: previewView, deviceTypes: Self.cameraTypes
        ) { [weak self] map in
            self?.update(map)          // main queue. No AVFoundation calls in here.
        }
    }

    private func update(_ map: AVCaptureDeviceDirectionMap) {
        directions = map
        let forward = map.forwardFacingDeviceDescriptors
        if let camera, forward.contains(where: { $0.uniqueID == camera.uniqueID }) { return }
        let wanted: AVCaptureDevice.Position = preference == .frontFirst ? .front : .back
        guard let next = forward.first(where: { $0.position == wanted }) ?? forward.first else {
            return                     // nothing faces the person right now
        }
        camera = next
        willSwitch()
        Task {
            // The descriptor is Sendable. The actor turns it into a device.
            if await capture.useCamera(withID: next.uniqueID) { didSwitch(next) }
        }
    }
}
#endif
```

Why it is built this way:

- The coordinator reports directions relative to a view, which is main-actor state. Apple asks you to create it and handle its updates on the main actor, and to keep a strong reference while the view is on screen (guide).
- The handler gets a direction map, not devices. Descriptors and maps are `Sendable` (`AVCaptureDeviceDirectionCoordinator.h`), so the watcher passes an ID to the actor and never touches AVFoundation itself.
- The first call arrives soon after you create the coordinator, with the directions at that moment. You don't need a separate step to read the starting state (guide).
- The order of `forwardFacingDeviceDescriptors` isn't documented. Choose by `position` and your preference, not by index alone.
- Keep the current camera while it still faces forward. Switch only when it leaves the forward list.

## Mirroring for each preview

`previewMirroring(for:in:)` is in SKILL.md section 4. This applies its answer, and keeps one view's mirroring right on its own. A preview on each display needs one each.

```swift
import AVKit
import UIKit

// requires: previewMirroring(for:in:) (SKILL.md), PreviewView (rotation-and-preview.md)

#if !targetEnvironment(macCatalyst)
@MainActor
func applyMirroring(_ mirrored: Bool?, to connection: AVCaptureConnection?) {
    guard let connection, connection.isVideoMirroringSupported else { return }
    guard let mirrored else {
        connection.automaticallyAdjustsVideoMirroring = true
        return
    }
    connection.automaticallyAdjustsVideoMirroring = false   // first, or the next line throws
    connection.isVideoMirrored = mirrored
}

/// Mirrors one preview by the direction its camera faces from that preview's own view.
/// From the outer display the rear cameras face forward; from the inner one, backward.
@available(iOS 27.1, *)
@MainActor
final class PreviewMirror {
    private var coordinator: AVCaptureDeviceDirectionCoordinator?
    private weak var view: PreviewView?
    private var directions: AVCaptureDeviceDirectionMap?
    var camera: AVCaptureDeviceDescriptor? { didSet { apply() } }

    func watch(_ view: PreviewView) {
        self.view = view
        coordinator = AVCaptureDeviceDirectionCoordinator(
            view: view, deviceTypes: DirectionWatcher.cameraTypes
        ) { [weak self] map in
            self?.directions = map
            self?.apply()
        }
    }

    /// Also call after every camera switch: a new input makes a new preview connection.
    func apply() {
        guard let camera, let directions else { return }
        applyMirroring(previewMirroring(for: camera, in: directions), to: view?.previewLayer.connection)
    }
}
#endif
```

| Camera | Seen from | Direction | Preview |
|---|---|---|---|
| Inner front | The inner display | Forward | Mirrored (automatic) |
| Outer front | The inner display | Backward | Not mirrored (override) |
| Rear | The inner display | Backward | Not mirrored (automatic) |
| Rear | The outer display, phone turned around, or the subject view | Forward | Mirrored (override) |
| Outer front | The outer display | Forward | Mirrored (automatic) |

The rows come from Apple's guide and talk 111465. None is checked on a device.

## UIKit

The same objects work in a view controller. The preview view is the coordinator's frame of reference.

```swift
import AVKit
import UIKit

// requires: CaptureService, DirectionWatcher, PreviewMirror (this file), PreviewView (rotation-and-preview.md)

#if !targetEnvironment(macCatalyst)
@available(iOS 27.1, *)
final class CameraViewController: UIViewController {
    private let capture = CaptureService()
    private lazy var watcher = DirectionWatcher(capture: capture)
    private let mirror = PreviewMirror()
    private let previewView = PreviewView()
    private let cover = UIView()

    override func loadView() { view = previewView }

    override func viewDidLoad() {
        super.viewDidLoad()
        capture.previewSource.connect(previewView.previewLayer)
        cover.backgroundColor = .black
        cover.isHidden = true
        cover.frame = previewView.bounds
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        previewView.addSubview(cover)

        watcher.willSwitch = { [weak self] in self?.cover.isHidden = false }
        watcher.didSwitch = { [weak self] camera in
            self?.mirror.camera = camera
            self?.cover.isHidden = true
        }
        watcher.watch(previewView)
        mirror.watch(previewView)
        Task { await capture.start() }
    }
}
#endif
```

- The view controller survives a fold; only its view resizes. Don't stop the session in `viewWillDisappear(_:)` because of a fold.
- If your app deploys below iOS 27.1, keep a second path that calls `capture.useFrontCamera()` and skips the watcher.

## Interruptions

`AVCaptureSession.h` lists `.videoDeviceNotAvailableWithMultipleForegroundApps`: the session stops when the app runs in a multi-app layout and its configuration needs the full screen. Split View on the inner display is a multi-app layout, so expect it there (unverified on Duo). Tell people why the preview froze. For the background case the header says the session starts again on its own when the interruption ends, as long as you didn't call `stopRunning()`; expect the same here (unverified).

```swift
import AVFoundation
import Observation

/// Tells people why the preview froze, and clears the message when capture resumes.
@MainActor @Observable
final class CaptureStatus {
    var message: String?

    func watch() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.listen(for: AVCaptureSession.wasInterruptedNotification) }
            group.addTask { await self.listen(for: AVCaptureSession.interruptionEndedNotification) }
        }
    }

    private func listen(for name: Notification.Name) async {
        for await note in NotificationCenter.default.notifications(named: name) {
            guard name == AVCaptureSession.wasInterruptedNotification else {
                message = nil
                continue
            }
            let raw = note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int
            switch raw.flatMap(AVCaptureSession.InterruptionReason.init(rawValue:)) {
            case .videoDeviceNotAvailableWithMultipleForegroundApps?:
                message = "The camera works when the app fills the screen."
            case .videoDeviceNotAvailableDueToSystemPressure?:
                message = "The camera paused to cool down."
            default:
                message = "The camera is in use elsewhere."
            }
        }
    }
}
```

Start it with `.task { await status.watch() }` on the camera screen.

- Video-call apps (the `voip` background mode) and apps with the `com.apple.developer.avfoundation.multitasking-camera-access` entitlement can keep the camera while multitasking. Check `isMultitaskingCameraAccessSupported`, then set `isMultitaskingCameraAccessEnabled` before the session starts (`AVCaptureSession.h`, [Accessing the camera while multitasking](https://developer.apple.com/documentation/avkit/accessing-the-camera-while-multitasking-on-ipad)).
- Apple's material treats a fold as a change of direction, handled by switching the input: the system does it for the virtual front camera, your watcher does it for the physical cameras. It names no interruption for a fold. What a session reports on a device while the phone closes is unverified, so keep the interruption handler anyway.

## Sources

IDs point to [`reference/sources.md`](https://github.com/Kimeur/duology/blob/main/reference/sources.md): D7 (camera direction guide), V4 (scenes talk: Split View), V5 (camera talk).
