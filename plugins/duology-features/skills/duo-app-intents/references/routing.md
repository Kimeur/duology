# Routing intents to panes and windows

How an intent reaches the right window and pane, in SwiftUI and UIKit, and what changes on iPhone Duo. The SwiftUI version is in SKILL.md section 2.

## How the system picks a scene

Apple's guide, in short ([Directing app intents to your app's scenes](https://developer.apple.com/documentation/appintents/directing-app-intents-to-your-apps-scenes)):

1. Only intents that adopt `TargetContentProvidingIntent` (SwiftUI) or `UISceneAppIntent` (UIKit) go to a scene. Others run without one.
2. Each intent has a `contentIdentifier`. The default comes from the intent type; return your own to include the item's ID.
3. SwiftUI matches it against `handlesExternalEvents(preferring:allowing:)` on a view in each scene, or `handlesExternalEvents(matching:)` on the scene. UIKit matches it against each scene's `activationConditions`.
4. The chosen scene gets the intent first (`onAppIntentExecution` or `scene(_:willPerformAppIntent:)`), then the system calls `perform()` and brings the app forward.
5. `UIApplicationSupportsMultipleScenes` must be `YES` for this to work at launch, even with one scene.

On iPhone Duo:

- Closed, there is one window on the outer display. Routing only decides what that window shows.
- Open, people can have two windows of your app side by side on the inner display (`duo-scenes`). Routing by `contentIdentifier` is how an intent finds the window that already shows the item. *Unverified* on Duo: which window wins when neither prefers the identifier.
- Closing the phone with two windows open leaves one on the outer display (`duo-scenes` didn't confirm which). An intent that arrives next goes to the scenes that are still connected; allowing `"*"` in every window keeps one available.

## UIKit

```swift
import UIKit
import AppIntents

// requires: Note, NoteEntity, NotesWindowModel (SKILL.md)

/// UIKit apps adopt UISceneAppIntent instead of TargetContentProvidingIntent.
struct OpenNoteInSceneIntent: OpenIntent, UISceneAppIntent {
    static let title: LocalizedStringResource = "Open Note"

    @Parameter(title: "Note") var target: NoteEntity

    var contentIdentifier: String { "note:\(target.id.uuidString)" }

    func perform() async throws -> some IntentResult { .result() }
}

final class NotesSceneDelegate: UIResponder, UIWindowSceneDelegate, @MainActor AppIntentSceneDelegate {
    var window: UIWindow?
    let model = NotesWindowModel()                 // one per window, as in SwiftUI

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        // Launched by the intent: show its note before the first frame.
        if let intent = connectionOptions.appIntent as? OpenNoteInSceneIntent {
            model.selection = intent.target.id
        }
        updateActivationConditions(for: scene)
    }

    // The app was already running: the system picked this scene for the intent.
    func scene(_ scene: UIScene, willPerformAppIntent appIntent: any UISceneAppIntent) {
        guard let intent = appIntent as? OpenNoteInSceneIntent else { return }
        model.selection = intent.target.id
        updateActivationConditions(for: scene)
    }

    /// Prefer intents for the note this window shows; accept the rest.
    func updateActivationConditions(for scene: UIScene) {
        let conditions = UISceneActivationConditions()
        if let id = model.selection {
            conditions.prefersToActivateForTargetContentIdentifierPredicate =
                NSPredicate(format: "self == %@", "note:\(id.uuidString)")
        }
        conditions.canActivateForTargetContentIdentifierPredicate = NSPredicate(value: true)
        scene.activationConditions = conditions
    }
}
```

- Use this intent or the SwiftUI `OpenNoteIntent`, not both. *Measured:* with both in one app, the build failed in the App Intents metadata step: an entity can be the target of only one `OpenIntent`.
- `AppIntentSceneDelegate` and `UIScene.ConnectionOptions.appIntent` are iOS 26 ([AppIntentSceneDelegate](https://developer.apple.com/documentation/appintents/appintentscenedelegate), [appIntent](https://developer.apple.com/documentation/uikit/uiscene/connectionoptions/appintent)).
- In Swift 6 mode, write the conformance as `@MainActor AppIntentSceneDelegate`. The protocol's method is not main-actor isolated, and a plain conformance doesn't compile (we typechecked both).
- Update the activation conditions whenever the window's selection changes, not only on connect. They match the same kind of target content identifier that `NSUserActivity.targetContentIdentifier` carries in `duo-scenes`. *Unverified:* activation-condition routing on iPhone Duo (`duo-scenes` lists it as untested too).
- Without `scene(_:willPerformAppIntent:)`, the system calls the intent's `performNavigation(forScene:)` instead ([UISceneAppIntent](https://developer.apple.com/documentation/appintents/uisceneappintent)). Use one or the other.
- Show the note by setting the window model's selection. With a `UISplitViewController`, choose the column that stays on top when it collapses on the closed phone in `splitViewController(_:topColumnForCollapsingToProposedTopColumn:)` (iOS 14): the secondary column when a note is selected. We measured the collapse only with SwiftUI's `NavigationSplitView`.

## The scene manifest

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <true/>
</dict>
```

- Check the built app: `plutil -p <App>.app/Info.plist | grep -A3 SceneManifest`. *Measured* in our probe: with `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES` and this partial Info.plist, the built app had the key set to true.
- The key also lets people open a second window. Make every window work on its own first (`duo-scenes` rules).

## Which pane

- With a `NavigationSplitView` or `UISplitViewController`, the selection decides the pane. Closed, the split view shows the detail; open, list and detail side by side.
- With your own two-pane layout (`duo-layout`), give the window model the state that layout reads ("which note", "is the side pane showing") and set it in the handler. Never reach into a view.
- With an assistant pane (`duo-intelligence`), an intent that summarizes the open note can set the pane's state too. Closed, the one-line summary shows; open, the full pane.
