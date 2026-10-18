# Evidence: what we measured

Every *measured* line in this skill comes from the runs below. Read the limits first.

- **When:** 18 October 2026.
- **Tools:** Xcode 27.1 (27A9275), iOS 27.1 simulator SDK, the shared "iPhone Duo" simulator on iOS 27.1. The probe app was built with `swiftc` and installed with `simctl`; logs came from `simctl launch --stdout`.
- **Pose:** closed, portrait, the whole time. The outer display was active (`devicectl device info displays` marked LCD active).
- **Device:** none. Nothing here has run on a real iPhone Duo.

## Limits

- **No open phone.** We tried to press Open in Device Hub through the macOS Accessibility API. The Mac's screen was locked: a hit test returned the login window, and Device Hub's window gave no usable accessibility tree. So every inner-display question (Split View, a second window beside the first, fold and unfold) is *unverified*.
- **No camera.** The simulator has none. Accessory results say only what happened with no capture session.
- **Shared simulator.** Other sessions used the same simulator. Before each launch we checked for running UI tests, and we waited while one ran.

## The probe

A SwiftUI app with one `WindowGroup`, `UIApplicationSupportsMultipleScenes` set to `YES`, and launch arguments that trigger actions on a timer (open a window, send a UIKit request, set a `@SceneStorage` value, present a menu). The core is below; it typechecks. Add it to a debug build of your own app to read the same events.

```swift
import SwiftUI
import UIKit

/// Logs every scene the app has, once a second, when something changes.
@MainActor
final class SceneCensus {
    static let shared = SceneCensus()
    private var last = ""
    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { SceneCensus.shared.log() }
        }
    }

    func log() {
        let app = UIApplication.shared
        var lines = ["multi=\(app.supportsMultipleScenes) open=\(app.openSessions.count) connected=\(app.connectedScenes.count)"]
        for case let scene as UIWindowScene in app.connectedScenes {
            let native = scene.screen.nativeBounds.size          // 1398 x 2034 outer, 2007 x 2853 inner
            let size = scene.effectiveGeometry.coordinateSpace.bounds.size
            lines.append("  \(scene.session.persistentIdentifier.suffix(6)) state=\(scene.activationState.rawValue) "
                + "screen=\(Int(native.width))x\(Int(native.height)) window=\(Int(size.width))x\(Int(size.height)) "
                + "h=\(scene.traitCollection.horizontalSizeClass.rawValue)")
        }
        let text = lines.joined(separator: "\n")
        if text != last { last = text; print("SCENES\n" + text) }
    }
}

final class ProbeAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        SceneCensus.shared.start()
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        guard session.role == .windowApplication else { return session.configuration }
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = ProbeSceneDelegate.self    // SwiftUI still owns the window
        return configuration
    }
}

final class ProbeSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func sceneWillResignActive(_ scene: UIScene) { print("resign", scene.session.persistentIdentifier.suffix(6)) }
    func sceneDidEnterBackground(_ scene: UIScene) { print("background", scene.session.persistentIdentifier.suffix(6)) }
    func sceneDidDisconnect(_ scene: UIScene) { print("disconnect", scene.session.persistentIdentifier.suffix(6)) }
    func windowScene(_ windowScene: UIWindowScene,
                     didUpdateEffectiveGeometry previous: UIWindowScene.Geometry) {
        print("geometry", previous.coordinateSpace.bounds.size, "->",
              windowScene.effectiveGeometry.coordinateSpace.bounds.size, windowScene.screen.nativeBounds.size)
    }
}

struct ProbeApp: App {                       // mark it @main in a probe target
    @UIApplicationDelegateAdaptor(ProbeAppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup(id: "main") { Text("Probe") }
    }
}
```

Run it with output in a file, change the pose in Device Hub, then read the file:

```bash
xcrun simctl launch --terminate-running-process --stdout="$PWD/scenes.log" booted com.example.probe
```

## Results (closed phone)

| What we did | What happened |
|---|---|
| Read `supportsMultipleScenes` and SwiftUI's `supportsMultipleWindows` | Both `true` |
| `openWindow(id:)` from the first window | No error. A second scene connected on the outer screen (1398 × 2034 px native, window 466 × 678 pt) and became active. The first went `inactive`, then `background`, and stayed connected. |
| `activateSceneSession(for: UISceneSessionActivationRequest())` | Same: a third scene, no error handler call |
| The covered window, while in the background | Two geometry updates: 466 × 678 to 951 × 669 pt (interface orientation landscape right), then back to 466 × 678 pt |
| The new window's first layout | Root view 466 × 562 pt, then 382 × 644 pt |
| Edit menu with `UIWindowScene.ActivationAction` (no alternate) and a plain `UIAction` | Only the plain action appeared |
| `UIWindowScene.ActivationAction(title: "A") { _ in config }` | Built with a warning; at launch threw `NSInternalInconsistencyException`, "Initializer is unavailable" |
| `CameraCaptureAccessory` with `onAvailabilityChange` | Called once with `false` at launch; the accessory content never appeared |
| `@SceneStorage` count set to 7 in window 1, then a new window | Window 2 read 0 |
| Terminate and relaunch | Only the last window used reconnected (open 2, connected 1), restored with activity type `com.apple.SwiftUI.stateRestoration` |
| `UISceneSessionActivationRequest(session:)` for the other open session | It reconnected and read 7 |
| Relaunch with two open sessions | The system showed a "2 Views Open" pill at the top of the outer display |

Sample log lines (trimmed):

```text
PROBE 3.3 [ADCE] AUTO openWindow, supportsMultipleWindows=true
PROBE 3.4 willResignActive scene B9BE15 ... screen=outer(1398x2034) window=466x678
PROBE 3.5 willConnect scene 4A3088 ... screen=outer(1398x2034) window=466x678 restoring=nil
PROBE 4.3 didEnterBackground scene B9BE15 ... state=2
PROBE 4.4 didUpdateEffectiveGeometry from 466x678 to scene B9BE15 ... window=951x669 orient=4
PROBE 0.1 [0706] accessory availability -> false
PROBE 3.4 [E734] root onAppear ... count=7
```

## Not verified yet

- Anything on the inner display: a second window beside the first, Split View sizes and size classes, the activation action's visibility, the `alternate:` replacing it on the outer display.
- Scene events during a fold or unfold, and which window survives a close from Split View.
- What a real iPhone Duo returns for a new-window request on the outer display (Apple says it fails).
- Camera capture accessory availability with a running capture session.
- `UISceneActivationConditions` routing on iPhone Duo.

## Typecheck

Every Swift block in this skill was extracted and typechecked as one file per Markdown file, with placeholder types where a block names your own views:

```bash
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer \
xcrun -sdk iphonesimulator swiftc -typecheck -target arm64-apple-ios27.1-simulator <file>.swift
```

We ran it in Swift 5 and Swift 6 language modes, at deployment targets iOS 27.1 and iOS 26.0 (the iOS 27 APIs are behind `@available` and `#available`), and in Swift 6 with `-default-isolation MainActor`. No errors and no warnings in any mode.
