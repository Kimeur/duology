# State restoration per window, and the scene lifecycle

Each window of your app is a scene with its own session. A session outlives its scene: the system can let a scene go and keep the session, then reconnect it later with the saved state. On iPhone Duo this matters for two reasons: people can now have several windows of one app, and opening or closing the phone moves a window between displays. Every Swift block on this page typechecks against the iOS 27.1 simulator SDK (see [evidence.md](evidence.md#typecheck)).

Fold and unfold inside one window (scroll position, playback, typed text) is `duo-continuity`'s job. This page covers what differs per window.

## SwiftUI

### What SwiftUI keeps for you

- `@SceneStorage` values, per window. Apple's [SceneStorage](https://developer.apple.com/documentation/swiftui/scenestorage) page says each scene has its own storage and that closing a window destroys it. Keep values small and never store secrets.
- The value a `WindowGroup(for:)` window presents. SwiftUI saves it and passes it back when it restores the window, or the default value if restoring fails ([WindowGroup](https://developer.apple.com/documentation/swiftui/windowgroup)).

*Measured* on the closed phone:

- A new window started with its own `@SceneStorage` value (0) while the first window held 7.
- After the app was terminated and relaunched, the system reconnected only the last window used (open sessions 2, connected 1).
- Activating the other saved session with `UISceneSessionActivationRequest(session:)` brought it back with 7.
- SwiftUI saved its windows with its own activity type, `com.apple.SwiftUI.stateRestoration`. Treat it as private.

### Per-window navigation

```swift
import SwiftUI

struct Note: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var title: String
}

/// The root of one window. Each window saves its own tab and path.
struct NotesWindowRoot: View {
    @SceneStorage("notes.tab") private var tab = 0
    @SceneStorage("notes.path") private var savedPath: Data?
    @State private var path: [Note.ID] = []
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $tab) {
            Tab("Notes", systemImage: "note.text", value: 0) {
                NavigationStack(path: $path) {
                    Text("Notes")
                        .navigationDestination(for: Note.ID.self) { Text($0.uuidString) }
                }
            }
            Tab("Search", systemImage: "magnifyingglass", value: 1) { Text("Search") }
        }
        .task {                                            // runs once: this root keeps its identity
            if let savedPath, let ids = try? JSONDecoder().decode([Note.ID].self, from: savedPath) {
                path = ids
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { savedPath = try? JSONEncoder().encode(path) }
        }
    }
}
```

- A window opened with `openWindow(value:)` already knows its note from the value. Use `@SceneStorage` for what changes after that.
- `duo-continuity` has the `NavigationPath` version and the rules for model ownership.

## UIKit

### Save and restore one window

```swift
import UIKit

final class NotesSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var list: NotesListController?
    static let browsingType = "com.example.notes.browsing"   // list it under NSUserActivityTypes

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        // A new window gets the request's activity; a restored window gets its saved one.
        let activity = connectionOptions.userActivities.first ?? session.stateRestorationActivity
        let list = NotesListController()
        list.selectedNoteID = (activity?.userInfo?["noteID"] as? String).flatMap(UUID.init(uuidString:))
        self.list = list

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: list)
        window.makeKeyAndVisible()
        self.window = window
    }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        let activity = NSUserActivity(activityType: Self.browsingType)
        if let id = list?.selectedNoteID {
            activity.targetContentIdentifier = id.uuidString
            activity.userInfo = ["noteID": id.uuidString]
        }
        return activity
    }
}

final class NotesListController: UITableViewController {
    var selectedNoteID: UUID?
}
```

- The system asks for the activity before it disconnects the scene and stores a copy in `session.stateRestorationActivity` ([doc](https://developer.apple.com/documentation/uikit/uiscenesession/staterestorationactivity)). That doc also says the value can be `nil` at connection time if the data is still locked, and is filled in later.
- Small per-window values that aren't worth an activity can go in `session.userInfo`.

### Bring back a window instead of duplicating it

```swift
import UIKit

@MainActor
func showNote(_ noteID: UUID, otherwise showHere: @escaping @MainActor @Sendable () -> Void) {
    let app = UIApplication.shared
    let existing = app.openSessions.first {
        $0.stateRestorationActivity?.targetContentIdentifier == noteID.uuidString
    }
    let request: UISceneSessionActivationRequest
    if let existing {
        request = UISceneSessionActivationRequest(session: existing)
    } else {
        let activity = NSUserActivity(activityType: "com.example.notes.open")
        activity.targetContentIdentifier = noteID.uuidString
        activity.userInfo = ["noteID": noteID.uuidString]
        request = UISceneSessionActivationRequest(userActivity: activity)
    }
    app.activateSceneSession(for: request) { _ in
        Task { @MainActor in showHere() }
    }
}
```

`openSessions` includes windows whose scene isn't connected. *Measured:* re-activating such a session reconnected it with its saved state.

### Clean up closed windows

When people close windows, UIKit reports the discarded sessions to the app delegate ([application(_:didDiscardSceneSessions:)](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:diddiscardscenesessions:))). Delete any per-window files there, but only for your own windows.

```swift
import UIKit

final class NotesAppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        for session in sceneSessions where session.role == .windowApplication {
            WindowFiles.remove(for: session.persistentIdentifier)
        }
    }
}

enum WindowFiles {
    static func remove(for sessionID: String) {
        let url = URL.applicationSupportDirectory.appending(path: "windows/\(sessionID).json")
        try? FileManager.default.removeItem(at: url)
    }
}
```

*Measured:* the callback fired for camera capture accessory sessions each time the accessory went away, which is why the loop filters on `role`. *Unverified:* how people close one of your windows on iPhone Duo; no app window was discarded in our runs.

## The lifecycle on fold and unfold

Apple says opening and closing the phone work like resizing the app in iPhone Mirroring ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=135)), and that the app still resizes on open and close even with `UIRequiresFullScreen` ([same talk](https://developer.apple.com/videos/play/tech-talks/111461/?time=277)). The UIKit header for `windowScene(_:didUpdateEffectiveGeometry:)` (iOS 26) says it is always called when a window scene moves between screens. Use that callback, or plain trait and size changes, to react. Read the screen from the scene when you need it.

```swift
import UIKit

final class PlayerSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var displayLink: CADisplayLink?

    func windowScene(_ windowScene: UIWindowScene,
                     didUpdateEffectiveGeometry previousEffectiveGeometry: UIWindowScene.Geometry) {
        let old = previousEffectiveGeometry.coordinateSpace.bounds.size
        let new = windowScene.effectiveGeometry.coordinateSpace.bounds.size
        guard old != new, windowScene.activationState == .foregroundActive else { return }
        // Size changed while someone is looking. Layout follows traits on its own;
        // only adjust things that don't, such as a render target size.
    }

    func startFrameUpdates(in windowScene: UIWindowScene) {
        if #available(iOS 27.0, *) {
            // Follows the scene when it moves to the other display.
            displayLink = windowScene.displayLink(target: self, selector: #selector(step))
        } else {
            displayLink = CADisplayLink(target: self, selector: #selector(step))
        }
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func step(_ link: CADisplayLink) {
        // Draw one frame.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        displayLink?.invalidate()
        displayLink = nil
    }
}
```

- `UIWindowScene.displayLink(target:selector:)` is iOS 27.0. Apple's doc says the link is retargeted when the scene moves between displays ([doc](https://developer.apple.com/documentation/uikit/uiwindowscene/displaylink(target:selector:))). `UIScreen`'s `displayLink(withTarget:selector:)` is deprecated in iOS 27.
- `windowScene.screen` changes when the window moves. Never keep a `UIScreen` in a property. `duo-layout` has the wider rule.

### What we saw, and what we couldn't check

*Measured* on the simulator, one window in front, pressing Closed and Open in Device Hub:

| Step | Scene events | SwiftUI |
|---|---|---|
| Open to closed | One `didUpdateEffectiveGeometry`: 951 × 669 pt on the inner screen to 466 × 678 pt on the outer screen. No resign or become-active calls. Same session. | Phase stayed `active`. Width class `regular` to `compact`. No new `onAppear`; `@State` kept. |
| Closed to open | One `didUpdateEffectiveGeometry` back to 951 × 669 pt on the inner screen | Phase stayed `active`. Root sizes 466 × 562, 951 × 553, then 867 × 635 pt within a tenth of a second. |

So a fold is a resize of the same scene, as Apple says. Your window code doesn't restart.

*Measured* on the closed phone, when a second window covered the first:

| Order | First window |
|---|---|
| 1 | `sceneWillResignActive`, SwiftUI phase `active` to `inactive` |
| 2 | `sceneDidEnterBackground`, phase `inactive` to `background`; the scene stayed connected |
| 3 | `didUpdateEffectiveGeometry` to 951 × 669 pt in landscape, then back to 466 × 678 pt, all while in the background |

The new window, meanwhile, laid out first at 466 × 562 pt and then at 382 × 644 pt (its root view inside the safe area).

*Unverified:*

- which window stays on screen when the phone closes with two windows in Split View, and what happens to the other one (Split View needs a drag in Device Hub, which we didn't script);
- Partially Open (we pressed only Closed and Open);
- all of it on a real iPhone Duo.

Run the probe in [evidence.md](evidence.md#the-probe), set up Split View by hand, press the poses, and read the log. Meanwhile:

- Save on `.background`. Never tear down (stop playback, clear drafts, release the UI) on `.inactive`.
- Check `activationState` before doing work in a geometry callback.
- Handle `sceneDidDisconnect(_:)` at any point: UIKit can disconnect a background scene to reclaim resources and keep its session ([Managing your app's life cycle](https://developer.apple.com/documentation/uikit/managing-your-app-s-life-cycle)).
