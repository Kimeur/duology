# Evidence: what we measured

Every *measured* line in this skill comes from the runs below. Read the limits first.

- **When:** 18 October 2026.
- **Tools:** Xcode 27.1 (27A9275), iOS 27.1 simulator SDK, the shared "iPhone Duo" simulator on iOS 27.1. The probe app was built with `swiftc` and installed with `simctl`; logs came from `simctl launch --stdout`.
- **Pose:** closed and portrait for most runs (`devicectl device info displays` marked LCD active). One session pressed Open, Closed, Open, Closed in Device Hub through the macOS Accessibility API, checked the active display after each press, and left the simulator closed.
- **Device:** none. Nothing here has run on a real iPhone Duo.

## Limits

- **Open phone, late.** At first the Mac's screen was locked: a hit test returned the login window and Device Hub gave no usable accessibility tree, so we couldn't press a pose. Once the screen was unlocked, the pose buttons worked and we ran the open-phone session below.
- **No Split View, no Partially Open.** Split View needs a drag on the home indicator, which we didn't script. We pressed only Closed and Open.
- **No camera.** The simulator has none. Accessory results say only what happened with no capture session.
- **Shared simulator.** Other sessions used the same simulator. Before each launch we checked for running UI tests, and we waited while one ran.

## The probe

A SwiftUI app with one `WindowGroup`, `UIApplicationSupportsMultipleScenes` set to `YES`, and launch arguments that trigger actions on a timer (open a window, send a UIKit request, set a `@SceneStorage` value, present a menu). We couldn't tap, so the menu test presented an edit menu from code with [UIEditMenuInteraction.presentEditMenu(with:)](https://developer.apple.com/documentation/uikit/uieditmenuinteraction/presenteditmenu(with:)) and listed the visible `UILabel` texts in every window. The core is below; it typechecks. It reads [connectedScenes](https://developer.apple.com/documentation/uikit/uiapplication/connectedscenes), [openSessions](https://developer.apple.com/documentation/uikit/uiapplication/opensessions), [effectiveGeometry](https://developer.apple.com/documentation/uikit/uiwindowscene/effectivegeometry) and [activationState](https://developer.apple.com/documentation/uikit/uiscene/activationstate-swift.property). Add it to a debug build of your own app to read the same events.

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
        setvbuf(stdout, nil, _IOLBF, 0)   // write each line now; a log file stays empty without this
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

Run it with output in a file, change the pose, then read the file while the app runs. To change the pose, ask the user to press it in Device Hub, or run `duo-pose set open` / `duo-pose set closed` from [duo-pose-matrix](https://github.com/Kimeur/duology/blob/main/plugins/duology-ship/skills/duo-pose-matrix/SKILL.md) if they want it scripted.

```bash
xcrun simctl launch --terminate-running-process --stdout="$PWD/scenes.log" booted com.example.probe
```

Keep the `setvbuf` line. When stdout goes to a file, the C library holds output in a block buffer until the process exits, and the next `--terminate-running-process` launch kills the app before it writes. Without the line, `scenes.log` stays at 0 bytes while the app runs, and the lines are lost (*measured*, on the simulator and on the Mac). To watch live instead, launch with `--console-pty` in place of `--stdout=...`.

## Results: closed phone

| What we did | What happened |
|---|---|
| Read `supportsMultipleScenes` and SwiftUI's `supportsMultipleWindows` | Both `true` |
| `openWindow(id:)` from the first window | No error. A second scene connected on the outer screen (1398 × 2034 px native, window 466 × 678 pt) and became active. The first went `inactive`, then `background`, and stayed connected. |
| `activateSceneSession(for: UISceneSessionActivationRequest())` | Same: a third scene, no error handler call |
| The covered window, while in the background | Two geometry updates: 466 × 678 to 951 × 669 pt (`effectiveGeometry.interfaceOrientation` raw value 4, `landscapeLeft`), then back to 466 × 678 pt, on the outer screen |
| One window, the whole app sent to the background (something else came to the front) | The same: resign, background, then 466 × 678 to 951 × 669 pt and back within 0.2 s, on the outer screen. Width class stayed `compact` (trait raw value 1) at both sizes. Seen twice (run 6 at 156.8-159.7 s, the open-and-fold session at 136.9-140.1 s after its last Closed). |
| The new window's first layout | Root view 466 × 562 pt, then 382 × 644 pt |
| Edit menu with `UIWindowScene.ActivationAction` (no alternate) and a plain `UIAction` | Only the plain action appeared |
| The same menu, with an `alternate:` action given | The alternate appeared where the window action would be, next to the plain action |
| `UIWindowScene.ActivationAction(title: "A") { _ in config }` | Built with a warning; at launch threw `NSInternalInconsistencyException`, "Initializer is unavailable" |
| `UIWindowScene.ActivationAction(title: "B") { _ in return config }` | No warning; created a `UIWindowSceneActivationAction` |
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

## Results: open and fold

One session, run between another session's UI tests: Open, launch the probe with the accessory on, a second window at 3 s, an edit menu at 7 s; then Closed, Open, Closed.

| What we did | What happened |
|---|---|
| Launch on the open phone | Window 951 × 669 pt on the inner screen (2007 × 2853 px native), regular width and height; root view 867 × 635 pt |
| Camera capture accessory, no capture session | Availability `false` then `true`; a scene with role `UIWindowSceneSessionRoleCameraCaptureAccessory` on the outer screen at 466 × 678 pt. UIKit didn't call `configurationForConnecting` for it. |
| `openWindow(id:)` | A second full-size window (951 × 669 pt) covered the first; the first went inactive, then background. The first window's accessory went unavailable and its session was discarded; the second window got its own. |
| The covered first window, in the background | At 4.5 s, still on the inner screen: one geometry update to 466 × 678 pt, and SwiftUI's width class went `regular` to `compact`. At 4.6 s: back to 951 × 669 pt and `regular`. No fold happened. |
| Another run (run 8): one window on the open phone, the whole app sent to the background | The same round trip at 236.1-236.2 s: 466 × 678 pt and `compact`, then 951 × 669 pt and `regular` |
| Edit menu with `ActivationAction` (no alternate) | The window action showed, next to the plain action |
| Closed | The front window's scene moved to the outer screen: one `didUpdateEffectiveGeometry` (951 × 669 to 466 × 678 pt), width class regular to compact, phase stayed `active`, no `onAppear`. The accessory went unavailable and its session was discarded. |
| Open | The same scene moved back: one geometry update, width class compact to regular, phase stayed `active`. A new accessory scene appeared; its content's `onAppear` ran again. |

Sample log lines (trimmed):

```text
PROBE  0.3 [30A6] accessory availability -> true
  scene B28572 role=UIWindowSceneSessionRoleCameraCaptureAccessory state=0 screen=outer(1398x2034) window=466x678
PROBE  3.5 willConnect scene EE5849 ... screen=inner(2007x2853) window=951x669 restoring=nil
PROBE  4.3 didDiscardSceneSessions ["B28572"]
PROBE  4.3 didEnterBackground scene 2D714B ... state=2 screen=inner(2007x2853) window=951x669
PROBE  4.5 [30A6] widthClass regular -> compact
PROBE  4.5 didUpdateEffectiveGeometry from 951x669 to scene 2D714B ... state=2 screen=inner(2007x2853) window=466x678
PROBE  4.6 [30A6] widthClass compact -> regular
PROBE  9.6 MENU labels=["Zeta New Window", "Zeta Plain"]
PROBE 14.4 didUpdateEffectiveGeometry from 951x669 to scene EE5849 ... state=0 screen=outer(1398x2034) window=466x678
PROBE 14.5 didDiscardSceneSessions ["7E34CB"]
PROBE 20.9 didUpdateEffectiveGeometry from 466x678 to scene EE5849 ... state=0 screen=inner(2007x2853) window=951x669
```

## Not verified yet

- Split View: window sizes and size classes, two windows of one app side by side, and which window survives a close from Split View.
- Partially Open.
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

The Mac Catalyst helper in [scene-accessories.md](scene-accessories.md#deploying-below-ios-271) was also typechecked for `arm64-apple-ios27.1-macabi` against the macOS SDK's iOSSupport frameworks: no issues with the guard. Without the guard, the same code fails there with "cannot find 'CameraCaptureAccessory' in scope".
