# Scene accessories

Extra content that the system shows for your app on another display. On iPhone Duo the one that matters is the camera capture accessory: your camera UI stays on the inner display and the person in front of the camera sees your accessory on the outer display. Every Swift block on this page typechecks against the iOS 27.1 simulator SDK (see [evidence.md](evidence.md#typecheck)).

Apple's sources: [Registering a camera capture accessory on iPhone Duo](https://developer.apple.com/documentation/avfoundation/registering-a-camera-capture-accessory-on-iphone-duo), [Tech Talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/?time=261), [sceneAccessory(content:)](https://developer.apple.com/documentation/swiftui/view/sceneaccessory(content:)), [UISceneAccessory](https://developer.apple.com/documentation/uikit/uisceneaccessory).

## The two kinds

| | Camera capture | External, non-interactive |
|---|---|---|
| SwiftUI | `CameraCaptureAccessory` (iOS 27.1) | `ExternalNonInteractiveAccessory` (iOS 27.0) |
| UIKit | `UISceneAccessory.cameraCapture(sceneConfiguration:)`, also with `userInfo:` (iOS 27.1) | `UISceneAccessory.externalNonInteractive(sceneConfiguration:)`, also with `userInfo:` (iOS 27.0) |
| Shows on | The outer display of iPhone Duo | A connected display or an AirPlay display |
| Touch | Yes. Keep it to one small task, such as tap to focus. | No |
| Scene role | `UISceneSession.Role.windowCameraCaptureAccessory` (iOS 27.1), set by the system | Apple doesn't say |

Both are unavailable on macOS, Mac Catalyst, tvOS, watchOS and visionOS in the SDK. Apple's page for the external accessory names only a connected display and AirPlay. Use it for a TV or a monitor, not to reach the outer display.

## When the camera capture accessory shows

The system decides. From Apple's guide and the talk, all of these must hold:

- The phone is fully open and your app is full screen on the inner display, not in Split View.
- Your app is in the foreground with a capture session running.
- The view or view controller that registered the accessory is on screen.
- It is the top-most registration of its kind. A deeper view that registers its own makes yours unavailable until people go back.

It goes away when capture stops, when the app leaves the foreground, when someone closes the phone, or when people turn it off. It is on by default.

Design for that:

- Show something the subject needs: a countdown, how much of them the camera sees, a script. Never a control the photographer needs.
- Expect it to appear and vanish while you're mid-task. Keep its state in your model, not in its views.
- The same code runs on every iPhone. Where the system can't show it, availability just stays `false`.
- A camera accessory and an external accessory don't compete. An app can show both at once.

## SwiftUI

### Shared model

```swift
import SwiftUI
import Observation

@MainActor @Observable
final class ShootModel {
    var secondsToStart: Int?
    var isRecording = false
    var showsSubjectView = true        // you own this
    var subjectViewAvailable = false   // the system owns this
}

struct SubjectView: View {
    let model: ShootModel
    var body: some View {
        if let seconds = model.secondsToStart {
            Text("\(seconds)").font(.system(size: 160, weight: .bold))
        } else {
            Label(model.isRecording ? "Recording" : "Ready", systemImage: "record.circle")
                .font(.largeTitle)
        }
    }
}

struct CameraPreview: View {
    var body: some View { Color.black.ignoresSafeArea() }
}
```

### Deploying below iOS 27.1

`sceneAccessory(content:)` is iOS 27.0 and `CameraCaptureAccessory` is iOS 27.1. Put both behind one check. If the target also builds for Mac Catalyst, add a compile-time guard: both are marked unavailable there, so `#available` alone doesn't build. The Xcode 27.1 release notes list the same kind of Catalyst build errors for iOS 27.1 APIs and suggest this guard ([release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)).

```swift
import SwiftUI

extension View {
    /// Shows the subject view on the outer display while this camera view captures.
    /// Does nothing before iOS 27.1 or on Mac Catalyst.
    @ViewBuilder
    func subjectAccessory(_ model: ShootModel) -> some View {
        #if !targetEnvironment(macCatalyst)
        if #available(iOS 27.1, *) {
            modifier(SubjectAccessory(model: model))
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#if !targetEnvironment(macCatalyst)
@available(iOS 27.1, *)
private struct SubjectAccessory: ViewModifier {
    @Bindable var model: ShootModel

    func body(content: Content) -> some View {
        content.sceneAccessory {
            CameraCaptureAccessory(isEnabled: $model.showsSubjectView) {
                SubjectView(model: model)
            }
            .onAvailabilityChange { model.subjectViewAvailable = $0 }
        }
    }
}
#endif

struct CameraScreen: View {
    @State private var model = ShootModel()

    var body: some View {
        NavigationStack {
            CameraPreview()
                .subjectAccessory(model)       // on the camera view, not the app root
                .toolbar {
                    if model.subjectViewAvailable {
                        Toggle("Subject View", systemImage: "person.crop.rectangle",
                               isOn: $model.showsSubjectView)
                    }
                }
        }
    }
}
```

- Attach it to the camera view. Attached at the app root, it would claim the outer display on screens that don't capture.
- Watch the content's lifecycle with `onAppear`, `onDisappear` and `scenePhase` inside the accessory view, as Apple's [sceneAccessory(content:)](https://developer.apple.com/documentation/swiftui/view/sceneaccessory(content:)) page suggests.

### Both accessories at once

```swift
import SwiftUI

@available(iOS 27.1, *)
struct PresenterCamera: View {
    @State private var model = ShootModel()

    var body: some View {
        CameraPreview()
            .sceneAccessory {
                CameraCaptureAccessory {
                    SubjectView(model: model)          // outer display
                }
                ExternalNonInteractiveAccessory {
                    SubjectView(model: model)          // TV or AirPlay display
                }
            }
    }
}
```

## UIKit

Register on the view controller that shows the camera, keep the registration, and read `isAvailable` in `updateProperties()` (iOS 26). Apple's guide says availability supports observation, and `UISceneAccessoryRegistration.h` says it is observable in `updateProperties` and `layoutSubviews`. So UIKit calls `updateProperties()` again when it changes. Mac Catalyst targets need the same `#if !targetEnvironment(macCatalyst)` guard as above around this code.

```swift
import UIKit
import SwiftUI

@available(iOS 27.1, *)
final class CaptureViewController: UIViewController {
    let model = ShootModel()                                  // the accessory reads the same object
    private var registration: UISceneAccessoryRegistration?
    private lazy var subjectToggle = UIBarButtonItem(
        title: "Subject View", image: UIImage(systemName: "person.crop.rectangle"),
        primaryAction: UIAction { [weak self] _ in self?.toggleSubjectView() })

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = subjectToggle
        let configuration = UISceneConfiguration()            // no Info.plist entry needed
        configuration.delegateClass = SubjectSceneDelegate.self
        registration = registerSceneAccessory(.cameraCapture(sceneConfiguration: configuration, userInfo: model))
    }

    override func updateProperties() {
        super.updateProperties()
        subjectToggle.isHidden = !(registration?.isAvailable ?? false)
        subjectToggle.isSelected = registration?.isEnabled ?? false
    }

    private func toggleSubjectView() {
        registration?.isEnabled.toggle()                     // turn off; don't unregister
        setNeedsUpdateProperties()
    }

    func stopOfferingSubjectView() {                          // the feature itself goes away
        if let registration { unregisterSceneAccessory(registration) }
        registration = nil
        setNeedsUpdateProperties()
    }
}

@available(iOS 27.1, *)
final class SubjectSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene,
              session.role == .windowCameraCaptureAccessory,
              let model = connectionOptions.sceneAccessoryUserInfo as? ShootModel else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: SubjectView(model: model))
        window.makeKeyAndVisible()
        self.window = window
    }
}
```

- `userInfo` only identifies the object for the new scene. Keep your own strong reference to it, as `model` does here (Apple's guide).
- Accessory scenes have no scene manifest entry; one would be ignored. The system sets the role.
- If your app delegate implements `application(_:configurationForConnecting:options:)`, return `connectingSceneSession.configuration` for any role you don't handle, so you never replace the accessory's delegate. *Measured* in a SwiftUI app: UIKit didn't call it for the accessory scenes.
- `application(_:didDiscardSceneSessions:)` reports accessory sessions too (*measured*: one each time the accessory went away). Skip sessions whose role is `windowCameraCaptureAccessory` when you clean up per-window data.
- `isEnabled` hides the content and keeps the registration. `unregisterSceneAccessory(_:)` removes it and dismisses anything on screen ([doc](https://developer.apple.com/documentation/uikit/uiviewcontroller/unregistersceneaccessory(_:))).

## Camera direction on each display

With the accessory on screen, your app has one view on each display. Apple's camera talk says to make a separate direction coordinator per view: from the outer display's view the rear cameras face forward, from the inner display's view they face backward ([Tech Talk 111465](https://developer.apple.com/videos/play/tech-talks/111465/?time=289)). The coordinator is in **AVKit**, and its handler runs on the main queue (`AVCaptureDeviceDirectionCoordinator.h`).

```swift
import AVKit
import UIKit

@available(iOS 27.1, *)
@MainActor
final class DirectionWatcher {
    private var coordinator: AVCaptureDeviceDirectionCoordinator?
    private(set) var forwardCameraIDs: [String] = []

    /// Call once for the camera view on the inner display and once for the accessory's view.
    init(view: UIView) {
        coordinator = AVCaptureDeviceDirectionCoordinator(
            view: view,
            deviceTypes: [.builtInWideAngleCamera, .builtInOuterUltraWideCamera, .builtInInnerUltraWideCamera]
        ) { [weak self] map in
            // Descriptors are Sendable; hand them to your capture actor instead of touching AVFoundation here.
            let ids = map.forwardFacingDeviceDescriptors.map(\.uniqueID)
            MainActor.assumeIsolated { self?.forwardCameraIDs = ids }
        }
    }
}
```

Camera choice and the virtual front camera are beyond this skill; see Apple's [Choosing a camera by the direction it faces](https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces).

## Test it

| Where | What you can check |
|---|---|
| Xcode Previews or the simulator | The accessory view's layout at the outer display's size, and that it reads the shared model. |
| iPhone Duo simulator | The fold part of the lifecycle, not the capture part. The simulator has no camera, and in the Duo simulator the accessory shows with no capture session (known issue in the [Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)). See the measured run below. |
| Real iPhone Duo | Everything else: open the phone, start capture, check the subject view appears; stop capture, close the phone, switch to Split View, push a screen that registers its own accessory, background the app. Each must hide the accessory and hide your toggle. Turn it off and on with the toggle. |

Apple's guide also asks you to test anything that depends on capture on a device before you ship.

### What the simulator did (*measured*)

SwiftUI probe, `CameraCaptureAccessory` on each window's root view, no capture session:

| Step | Availability | Scenes |
|---|---|---|
| Launch, phone closed | `false` once | the app's window only |
| Launch, phone open | `false`, then `true` 0.1 s later | a second scene, role `windowCameraCaptureAccessory`, on the outer screen at 466 × 678 pt; the accessory content appeared |
| A second window opened in front | first window `false`, second window `true` | the first window's accessory session was discarded; a new one served the second window |
| Phone closed | `false` | the accessory session was discarded; the window moved to the outer screen |
| Phone opened again | `true` | a new accessory scene; the content's `onAppear` ran again |

So the fold behaviour matches Apple's guide. Keep accessory state in the model: each reopen builds new views.
