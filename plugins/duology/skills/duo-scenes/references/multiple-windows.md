# Multiple windows on iPhone Duo

How to open, route and refuse windows, in SwiftUI and UIKit. Every Swift block on this page typechecks against the iOS 27.1 simulator SDK in Swift 5 and Swift 6 mode (see [evidence.md](evidence.md#typecheck)). *Measured* lines come from the iPhone Duo simulator, closed and fully open.

## What Apple says, and what we saw

| | Apple | Simulator (*measured*) |
|---|---|---|
| More than one window | Supported for apps that support it on iPad ([Tech Talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/?time=218)) | `supportsMultipleScenes` and `supportsMultipleWindows` were `true`, closed and open |
| New window on the outer display | Can't be created; handle the error ([111464](https://developer.apple.com/videos/play/tech-talks/111464/?time=233)) | `openWindow(id:)` and `activateSceneSession(for:)` both succeeded. The new window covered the old one. No error handler ran. |
| New window on the inner display | Allowed | `openWindow(id:)` opened a full-size window (951 × 669 pt) over the first one. Not side by side. |
| `UIWindowScene.ActivationAction` | Hides itself when a new window isn't possible ([111464](https://developer.apple.com/videos/play/tech-talks/111464/?time=248)) | Shown on the open phone. On the closed phone: missing with `alternate: nil`, replaced by the alternate when one was given. |

Write code that is correct in every case: a request may fail, or cover the current window. People put two windows side by side themselves, by dragging.

## Turn it on

Set `UIApplicationSupportsMultipleScenes` to `YES` inside `UIApplicationSceneManifest` ([doc](https://developer.apple.com/documentation/bundleresources/information-property-list/uiapplicationscenemanifest/uiapplicationsupportsmultiplescenes)). With a generated Info.plist, Xcode's build setting `INFOPLIST_KEY_UIApplicationSceneManifest_Generation` generates a manifest meant for multi-window apps, according to the setting's description in Xcode 27.1. Check the built file rather than trusting either:

```bash
plutil -p build/Debug-iphonesimulator/MyApp.app/Info.plist | grep -A3 UIApplicationSceneManifest
```

Before you turn it on, make sure two windows of your app can run at once:

- Screen state lives in a model created by each window's root view, never in a global or a singleton.
- Shared data (a store, the signed-in user, a database) lives one level up, in the `App` or the app delegate, and handles two writers.
- Nothing assumes "the" window: no `UIApplication.shared.windows.first`, no `keyWindow` lookups to present from. Present from your own view controller or view.

## SwiftUI

### One window group per kind of content

`WindowGroup(for:)` takes a `Codable` and `Hashable` value, usually an ID. `openWindow(value:)` brings an existing window with that value forward instead of opening a second one ([OpenWindowAction](https://developer.apple.com/documentation/swiftui/openwindowaction)). The SKILL.md example uses this. Pass IDs, not whole models: the value is saved with the window and restored after a relaunch.

### Open by ID, close your own window

```swift
import SwiftUI

struct ComposeApp: App {                       // mark it @main in your app
    var body: some Scene {
        WindowGroup { InboxView() }
        WindowGroup("New Message", id: "compose") { ComposeView(inWindow: true) }
    }
}

struct InboxView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var composing = false

    var body: some View {
        NavigationStack {
            Text("Inbox")
                .toolbar {
                    Button("New Message", systemImage: "square.and.pencil") { composing = true }
                        .contextMenu {
                            Button("New Message in Window", systemImage: "plus.rectangle.on.rectangle") {
                                openWindow(id: "compose")
                            }
                        }
                }
                .sheet(isPresented: $composing) { ComposeView(inWindow: false) }   // the main way: works everywhere
        }
    }
}

struct ComposeView: View {
    let inWindow: Bool                         // true in its own window, false in the inbox's sheet
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button("Send") {
            if inWindow {
                dismissWindow()                // closes only this window
            } else {
                dismiss()                      // closes only the sheet; the inbox window stays
            }
        }
    }
}
```

- The button opens a sheet. The context menu offers a window as an extra.
- Close only the container you are in. Plain [dismissWindow()](https://developer.apple.com/documentation/swiftui/dismisswindowaction/callasfunction()) closes the current window. [dismissWindow(id:)](https://developer.apple.com/documentation/swiftui/dismisswindowaction/callasfunction(id:)) with a `WindowGroup` id closes every open window of that group, so one Send would throw away the other drafts. Don't call plain `dismissWindow()` from the sheet either: there the current window is the inbox.
- [dismissWindow](https://developer.apple.com/documentation/swiftui/environmentvalues/dismisswindow) is iOS 17 and later.
- *Measured:* `supportsMultipleWindows` was `true` on both displays, so it can't hide the window option on the outer display. SwiftUI has no built-in equivalent of the UIKit action that hides itself.

### When you need to know if it failed

You can't, in SwiftUI. `openWindow` reports nothing back, so don't build a flow that waits for its result. Make the in-window path the fallback that always works: the `NavigationLink` in the SKILL.md example, or the sheet above. The window is only an extra.

Don't swap in UIKit's request to get an error handler. A [UISceneSessionActivationRequest](https://developer.apple.com/documentation/uikit/uiscenesessionactivationrequest-swift.struct) has no public way to carry the value that `WindowGroup(for:)` presents. Even when it succeeds, the new window gets no value: expect the group's default ("Note not found" in the SKILL.md example) or a window of another group. *Measured:* a bare `UISceneSessionActivationRequest()` from a SwiftUI app with one `WindowGroup` opened a window of that group with no activity. We didn't test routing a request to one of several groups.

## UIKit

### Ask, then fall back

[activateSceneSession(for:errorHandler:)](https://developer.apple.com/documentation/uikit/uiapplication/activatescenesession(for:errorhandler:)) (iOS 17) replaces [requestSceneSessionActivation(_:userActivity:options:errorHandler:)](https://developer.apple.com/documentation/uikit/uiapplication/requestscenesessionactivation(_:useractivity:options:errorhandler:)). Both take an error handler. The errors are [UISceneError.Code](https://developer.apple.com/documentation/uikit/uisceneerror/code) values:

| Code | Meaning |
|---|---|
| `.multipleScenesNotSupported` | The app or the platform doesn't support more than one scene |
| `.requestDenied` | The system refused this request |

Apple doesn't say which code the outer display returns. Handle any error the same way: show the content in the current window. SKILL.md section 3 has `openInNewWindow(noteID:otherwise:)`.

### Read the request in the new window

The new scene gets the activity in its connection options ([userActivities](https://developer.apple.com/documentation/uikit/uiscene/connectionoptions/useractivities)). A restored scene gets its saved activity from the session instead ([stateRestorationActivity](https://developer.apple.com/documentation/uikit/uiscenesession/staterestorationactivity)).

```swift
import UIKit

final class NoteSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    static let openType = "com.example.notes.open"     // list it under NSUserActivityTypes

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let activity = connectionOptions.userActivities.first { $0.activityType == Self.openType }
            ?? session.stateRestorationActivity
        let noteID = (activity?.userInfo?["noteID"] as? String).flatMap(UUID.init(uuidString:))

        let root = UINavigationController(rootViewController: NoteListController(openNote: noteID))
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = root
        window.makeKeyAndVisible()
        self.window = window

        // Route later requests for the same note to this window instead of a new one.
        if let noteID {
            let match = NSPredicate(format: "self == %@", noteID.uuidString)
            windowScene.activationConditions.canActivateForTargetContentIdentifierPredicate = match
            windowScene.activationConditions.prefersToActivateForTargetContentIdentifierPredicate = match
        }
    }
}

final class NoteListController: UITableViewController {
    private let openNote: UUID?
    init(openNote: UUID?) {
        self.openNote = openNote
        super.init(style: .plain)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}
```

- The activity's [targetContentIdentifier](https://developer.apple.com/documentation/foundation/nsuseractivity/targetcontentidentifier) is matched against these predicates. Set it on every activity you send (`NoteActivity.make(noteID:)` in SKILL.md does).
- [UISceneActivationConditions](https://developer.apple.com/documentation/uikit/uisceneactivationconditions) dates from iOS 13. We did not test its routing on iPhone Duo.

### Menus: ActivationAction with an alternate

The handler returns a [UIWindowScene.ActivationConfiguration](https://developer.apple.com/documentation/uikit/uiwindowscene/activationconfiguration) that carries the activity for the new window.

```swift
import UIKit

final class NotesViewController: UICollectionViewController {
    var noteIDs: [UUID] = []

    override func collectionView(_ collectionView: UICollectionView,
                                 contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
                                 point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first else { return nil }
        let noteID = noteIDs[indexPath.item]
        return UIContextMenuConfiguration(actionProvider: { [weak self] _ in
            let inPlace = UIAction(title: "Open", image: UIImage(systemName: "doc.text")) { _ in
                self?.show(noteID)
            }
            let newWindow = UIWindowScene.ActivationAction(title: "Open in New Window", alternate: inPlace) { _ in
                let activity = NSUserActivity(activityType: "com.example.notes.open")
                activity.targetContentIdentifier = noteID.uuidString
                activity.userInfo = ["noteID": noteID.uuidString]
                return UIWindowScene.ActivationConfiguration(userActivity: activity)
            }
            return UIMenu(children: [newWindow])   // never list `inPlace` again: it would show twice
        })
    }

    func show(_ noteID: UUID) {
        // Push the note in this window.
    }
}
```

- The `alternate:` action replaces the window action where multiple windows aren't supported, and runs when the request fails (Apple's `UIWindowSceneActivationAction.h`).
- *Measured* on the closed phone: with an alternate, the menu showed the alternate where the window action would be; with `alternate: nil`, it showed nothing for it. So list the in-place action only as the alternate, or the outer display shows it twice.
- Tapping the cell stays the main way to open a note. If your menu is the only way in, always pass an alternate.
- *Measured:* on the open phone the window action showed as itself.

### The initializer trap

```swift
import UIKit

@MainActor
func makeActions(_ activity: NSUserActivity) -> [UIAction] {
    // Crashes at runtime: Swift picks UIAction's handler initializer, and the
    // closure's result is thrown away (compiler warning: "result ... is unused").
    // let broken = UIWindowScene.ActivationAction(title: "New Window") { _ in
    //     UIWindowScene.ActivationConfiguration(userActivity: activity)
    // }

    let labeled = UIWindowScene.ActivationAction(title: "New Window", alternate: nil) { _ in
        UIWindowScene.ActivationConfiguration(userActivity: activity)
    }
    let explicit = UIWindowScene.ActivationAction(title: "New Window") { _ in
        return UIWindowScene.ActivationConfiguration(userActivity: activity)
    }
    return [labeled, explicit]
}
```

*Measured:* the commented form built with one warning, then threw `NSInternalInconsistencyException` at launch: "Initializer is unavailable. Please use init(title:image:identifier:discoverabilityTitle:attributes:alternate:_:)". The explicit `return` form built a real `UIWindowSceneActivationAction` with no warning. Treat that warning as an error in review.

### Ask before a window with unsaved work closes

iOS 27.0 adds [closureConfirmation](https://developer.apple.com/documentation/uikit/uiwindowscene/closureconfirmation) on `UIWindowScene`. When it is set, the system shows a confirmation before a close that people start themselves. By default the dialog has a Close and a Cancel button. A `.cancel` action you pass replaces Cancel, and a `.destructive` one replaces Close ([UISceneClosureConfirmation](https://developer.apple.com/documentation/uikit/uisceneclosureconfirmation)).

```swift
import UIKit

final class DraftSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    /// Call when the draft in this window gains or loses unsaved changes.
    func draftDidChange(hasUnsavedChanges: Bool, in windowScene: UIWindowScene) {
        guard #available(iOS 27.0, *) else { return }
        if hasUnsavedChanges {
            let keep = UIAlertAction(title: "Keep Editing", style: .cancel)
            windowScene.closureConfirmation = UISceneClosureConfirmation(
                title: "Close this draft?",
                message: "Your changes in this window are not saved.",
                actions: [keep])                     // the system keeps its Close button
        } else {
            windowScene.closureConfirmation = nil
        }
    }
}
```

- Set it only while there is something to lose, and clear it after saving.
- Still save on `.background`. A confirmation doesn't cover the system ending a background app.
- SwiftUI has no matching modifier in the iOS 27.1 SDK.
- *Unverified:* how people close one window on iPhone Duo and whether this dialog appears there. We didn't close a window in our runs.

## Split View

All apps take part; there is nothing to adopt ([111464](https://developer.apple.com/videos/play/tech-talks/111464/?time=184)). Your window gets half the inner display, with its bars on the outer edge: left for the left app ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls)). A pinned Picture in Picture video can take the top of the screen and shrink your window vertically ([Tech Talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=201)).

- Lay out from your window's size and size class, never the screen. `duo-layout` covers the rules.
- If you limit orientations, the inner display scales your app instead, Split View included ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=285)).
- *Unverified:* the window size and size classes in Split View. Measure them with the probe in [evidence.md](evidence.md#the-probe) after you drag the app to one side.
- *Unverified:* whether two windows of the same app can share Split View, as on iPad. Build each window to work alone at half width either way.
