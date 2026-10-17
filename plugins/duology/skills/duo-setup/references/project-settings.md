# Project settings for an iPhone Duo app

The build settings and project format Duology recommends, why, and how to check them.

Checked on 16 October 2026 with Xcode 27.1 (27A9275). The two app-code Swift blocks below typecheck against the iOS 27.1 simulator SDK, and also build inside a test app with Swift 6, `MainActor` default isolation, approachable concurrency and a deployment target of iOS 26.0. The package manifest builds with `xcrun swift build`.

## SDK first, deployment target second

Two settings sound alike and do different things:

- **The SDK** is the one inside the Xcode you build with. It decides how the app behaves on iPhone Duo. Built with the iOS 26 SDK, the app sits at a familiar iPhone size in the middle of the inner display. With the iOS 27 SDK it fills most of it but avoids the status bar. With the iOS 27.1 SDK it goes edge to edge and its toolbars and tab bars turn vertical ([Apple: Three steps](https://developer.apple.com/iphone-duo/prepare/)). Check it with `SDK_VERSION` in `-showBuildSettings`.
- **The deployment target** (`IPHONEOS_DEPLOYMENT_TARGET`) is the oldest iOS the app runs on. It decides which APIs you may call without an availability check.

From April 2027, App Store uploads must be built with the iOS 27 SDK or later and target iOS 15 or later ([Apple: Submitting](https://developer.apple.com/app-store/submitting/)). Xcode 27.1 offers deployment targets from iOS 15.0 to 27.1 (`DEPLOYMENT_TARGET_SUGGESTED_VALUES` in `-showBuildSettings`), and debugs on devices running iOS 17 or later ([release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)).

## What Xcode 27.1's new-app template writes

We read the templates inside Xcode 27.1 (`Library/Xcode/Templates/Project Templates`):

| Setting | Template value | Duology recommends |
|---|---|---|
| `IPHONEOS_DEPLOYMENT_TARGET` | `latest_iphoneos`, a placeholder for the newest iOS the Xcode knows | `27.1` for a Duo-first app; lower it on purpose for wider reach |
| `TARGETED_DEVICE_FAMILY` | `1,2` | Keep. It must include `1` (iPhone). |
| `SWIFT_VERSION` | `5.0` | **Change to `6.0`** |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` (app targets) | Keep |
| `SWIFT_APPROACHABLE_CONCURRENCY` | `YES` | Keep |
| `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` | `YES` | Keep |
| `LOCALIZATION_PREFERS_STRING_CATALOGS` | `YES` | Keep |
| `ENABLE_USER_SCRIPT_SANDBOXING` | `YES` | Keep |
| iPhone orientations | Portrait, Landscape Left, Landscape Right | Keep (see [Orientations](#orientations-and-full-screen)) |

Read a project's real values:

```bash
xcodebuild -scheme <Scheme> -showBuildSettings 2>/dev/null | grep -E \
  "^ *(SWIFT_VERSION|SWIFT_DEFAULT_ACTOR_ISOLATION|SWIFT_APPROACHABLE_CONCURRENCY|IPHONEOS_DEPLOYMENT_TARGET|TARGETED_DEVICE_FAMILY|SDK_VERSION) ="
```

To try a value for one build without editing the project, add it to the command, for example `xcodebuild ... SWIFT_VERSION=6.0 build`. To keep it, change it in the target's Build Settings in Xcode, or edit the matching line in `project.pbxproj` for every configuration (Debug and Release).

## Swift 6 language mode

`SWIFT_VERSION = 6.0` turns data races into compile errors. Strict concurrency checking is always complete in Swift 6 mode ([Apple: build settings](https://developer.apple.com/documentation/xcode/build-settings-reference#Strict-Concurrency-Checking), [Apple: Adopting strict concurrency in Swift 6 apps](https://developer.apple.com/documentation/swift/adoptingswift6)).

- New app: set it on day one.
- Existing app: ask the user first. The switch can bring many errors at once. Apple suggests turning on upcoming features and complete checking in Swift 5 mode first, then switching ([Apple: Adopting strict concurrency in Swift 6 apps](https://developer.apple.com/documentation/swift/adoptingswift6)). The [Swift migration guide](https://www.swift.org/migration/documentation/migrationguide/) covers the common fixes.

## Default `MainActor` isolation

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` makes unannotated code in the target main-actor isolated ([Apple: build settings](https://developer.apple.com/documentation/xcode/build-settings-reference#Default-Actor-Isolation)). UI code and view models need no `@MainActor`. Code that must run elsewhere opts out:

```swift
import Foundation
import Observation

// With SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, this class is
// main-actor isolated without any annotation. SwiftUI views can own it.
@Observable
final class LibraryModel {
    var titles: [String] = []

    func reload() async {
        titles = await TitleLoader().loadTitles()
    }
}

// Plain logic that must run anywhere (tests on the Mac, background work):
// opt the type out of the default with `nonisolated`.
nonisolated struct TitleLoader: Sendable {
    // With approachable concurrency, a nonisolated async function runs on
    // the caller's actor. `@concurrent` moves the work off the main actor.
    @concurrent
    func loadTitles() async -> [String] {
        (1...3).map { "Title \($0)" }
    }
}
```

What the compiler says when you forget: a `nonisolated` function that writes to a property of a default-isolated class fails with "main actor-isolated property ... can not be mutated from a nonisolated context". Fix it by making the type `nonisolated` too, or by hopping to the main actor.

## Approachable concurrency

`SWIFT_APPROACHABLE_CONCURRENCY = YES` turns on five upcoming features: `DisableOutwardActorInference`, `GlobalActorIsolatedTypesUsability`, `InferIsolatedConformances`, `InferSendableFromCaptures` and `NonisolatedNonsendingByDefault` ([Apple: build settings](https://developer.apple.com/documentation/xcode/build-settings-reference#Approachable-Concurrency)).

In Swift 6 mode, three of them are already on; the Swift 6.4 compiler warns "already enabled" when you pass them. So, next to `SWIFT_VERSION = 6.0`, the setting adds two behaviours:

- **`NonisolatedNonsendingByDefault`**: a nonisolated `async` function runs on the caller's actor. Mark it `@concurrent` to run it on the shared pool.
- **`InferIsolatedConformances`**: a global-actor type's protocol conformances are isolated to that same actor, unless you mark them `nonisolated`.

## Deployment target and availability

Arrangements, reserved regions, the hinge and the vertical-bar APIs are iOS 27.1 ([Duology API index](https://github.com/Kimeur/duology/blob/main/reference/api-index.md)). Some bar and sheet APIs, such as `presentationPlacement(_:)` and `defaultTabBarPlacement(_:)`, are iOS 27.0.

- Deployment target 27.1: call them directly.
- Lower target: gate every one. Without the gate the build fails, for example "'onHingeChange(isEnabled:_:)' is only available in iOS 27.1 or newer".

```swift
import SwiftUI

// Deployment target below iOS 27.1: gate every Duo API with #available.
struct NotesScreen: View {
    var body: some View {
        if #available(iOS 27.1, *) {
            ArrangementView {
                NotesList()
            } secondary: {
                NoteDetail()
            }
        } else {
            HStack(spacing: 0) {
                NotesList()
                NoteDetail()
            }
        }
    }
}

struct NotesList: View {
    var body: some View {
        List(["Groceries", "Ideas"], id: \.self) { Text($0) }
    }
}

struct NoteDetail: View {
    var body: some View {
        Text("Pick a note")
    }
}
```

The `else` branch stands for whatever layout the app used before. Choosing the layout itself is `duo-layout`'s job.

Two Xcode 27.1 known issues for apps that also build for Mac Catalyst ([release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)): code using iOS 27.1-only APIs fails to compile for Catalyst, so wrap it in `#if !targetEnvironment(macCatalyst)`; and a target of iOS 27.1 shows no Mac Catalyst run destination until you add a Mac Catalyst 27.0 minimum deployment.

## Swift packages

Packages don't read the app's build settings. Set the same choices in `Package.swift`. With `swift-tools-version: 6.2`, targets build in Swift 6 mode, and `.defaultIsolation(MainActor.self)` sets the default isolation per target:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DuoEngine",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "DuoEngine", targets: ["DuoEngine"])],
    targets: [
        // Pure logic: no default isolation, so tests run anywhere.
        .target(name: "DuoEngine"),
        .target(name: "DuoUI", swiftSettings: [.defaultIsolation(MainActor.self)]),
        .testTarget(name: "DuoEngineTests", dependencies: ["DuoEngine"]),
    ]
)
```

We built this package and ran its tests with `xcrun swift test` on the Mac. Keeping game rules or business logic in a package like `DuoEngine` lets you test it without the simulator.

## Synchronized folders

Xcode can map a folder on disk straight into the project. Apple calls these folders, as opposed to groups; projects that use them have `objectVersion = 77` in `project.pbxproj`. Adding or removing a file on disk updates the project with no edit to `project.pbxproj`, which also means fewer merge conflicts ([Apple: Managing files and folders](https://developer.apple.com/documentation/xcode/managing-files-and-folders-in-your-xcode-project)). For an agent, that means a new Swift file in the folder is part of the target at the next build.

Check:

```bash
grep -E "objectVersion|isa = PBXFileSystemSynchronizedRootGroup" <App>.xcodeproj/project.pbxproj
```

Pass when you see `objectVersion = 77;` and at least one `PBXFileSystemSynchronizedRootGroup`.

- Older project: the user selects the groups in the Project navigator, Control-clicks and chooses Convert to Folder. Xcode converts only groups that match the folders on disk, and lists the rest.
- To keep a file out of a target, change its target membership in the File inspector. Xcode records that as an exception set (`PBXFileSystemSynchronizedBuildFileExceptionSet`) in the project file.
- Xcode 27 also reads a new JSON project file, `.xcproj`, which becomes the default in Xcode 27.2 ([Apple: project file format](https://developer.apple.com/documentation/xcode/updating-your-xcode-project-configuration-file-format)). Only Xcode 27 and later can open it. Keep `project.pbxproj` while anyone on the team still uses Xcode 26.

## Orientations and full screen

- Keep the template's iPhone orientations. The outer display honours them like any iPhone. The inner display doesn't; there, the app is scaled to fit, Split View included ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)).
- Remove `UIRequiresFullScreen`. Apple deprecated it in iOS 26 ([TN3192](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key)). Even when it is honoured, the app still resizes when the phone opens or closes ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)).
- Never branch on `UIScreen.main`, the device orientation or `userInterfaceIdiom` for layout. Use size classes and the view's own geometry. `UIScreen.main` is deprecated since iOS 26 ([Apple: UIScreen.main](https://developer.apple.com/documentation/uikit/uiscreen/main)).
