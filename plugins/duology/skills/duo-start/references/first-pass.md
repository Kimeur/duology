# The five-minute first pass

The first pass tells you how far the app is from working on iPhone Duo. It changes nothing in the app, except an optional debug logger that you remove at the end. Budget about five minutes after the build finishes. Don't fix anything during the pass.

Every block that calls `xcodebuild` or `xcrun` starts with `export DEVELOPER_DIR=...` for Xcode 27.1. Run each block as one command and keep that first line. Agent shells often drop `export` and shell variables between calls, and without it a plain `xcodebuild` or `xcrun` uses the Mac's default Xcode, which may be an older one.

## 1. Build with Xcode 27.1

Run this from the folder that holds the project ([detect.md](detect.md) prints it).

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer
xcodebuild -scheme <Scheme> \
  -destination 'platform=iOS Simulator,name=iPhone Duo,OS=27.1' \
  -derivedDataPath "$TMPDIR/duo-first-pass" build 2>&1 \
  | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'
```

- Add `-workspace <Name>.xcworkspace` (CocoaPods, several projects) or `-project <Name>.xcodeproj` when the folder holds more than one.
- `-derivedDataPath` keeps the build out of the repo and makes the app easy to find.
- *Measured:* with Xcode 27.1, `xcodebuild -scheme <Scheme> -showdestinations` lists the simulator with `platform:iOS Simulator`, `OS:27.1` and `name:iPhone Duo`. If it is missing, load `duo-setup`.
- Xcode 27.1 brings the iOS 27.1 SDK and Swift 6.4. Some new errors come from the [`@State` and `ContentBuilder` source changes](https://developer.apple.com/documentation/technotes/tn3211-resolving-swiftui-source-incompatibilities-for-state-and-contentbuilder) Apple describes in TN3211. Count the errors and list the first three. Load `duo-swiftui-27` (plugin `duology-features`), which covers TN3211.

## 2. Run duo-lint

Load the `duo-lint` skill (plugin `duology-ship`) and run it on the source folders. Keep the count and the top five findings.

### No duo-lint yet

If `duo-lint` isn't installed, run this rough grep. It lists lines that use the patterns Apple's [prepare page](https://developer.apple.com/iphone-duo/prepare/) tells you to remove. It skips `//` comment lines but not trailing comments, and it can't tell good uses from bad ones. Treat it as a pointer list, not a verdict.

```bash
#!/bin/bash
# Rough stand-in for duo-lint: lists lines that use patterns Apple's
# iPhone Duo prepare page tells you to remove. Read-only. Skips // comment lines.
# Usage: bash duo-quick-grep.sh [source folder, default .]
ROOT=${1:-.}
scan() {  # $1 = label, $2 = extended regex
  find "$ROOT" \( -name .git -o -name Pods -o -name Carthage -o -name .build -o -name build \
      -o -name DerivedData -o -name SourcePackages \) -prune \
      -o -type f \( -name '*.swift' -o -name '*.m' -o -name '*.mm' \) -print0 \
    | xargs -0 grep -HnE "$2" 2>/dev/null \
    | grep -vE ':[0-9]+:[[:space:]]*//' \
    | sed "s|^|[$1] |"
}
scan main-screen  'UIScreen\.main|UIScreen mainScreen|UIScreen\.screens'
scan orientation  'UIDevice\.current\.orientation|statusBarOrientation|\.interfaceOrientation'
scan idiom        'userInterfaceIdiom|\bisI?Pad\b'
scan window-frame 'UIWindow\(frame:'
scan fixed-size   '(bounds|size|frame)\.(width|height)[[:space:]]*==[[:space:]]*[0-9]{3}'
scan fill-media   'scaleAspectFill|contentMode:[[:space:]]*\.fill'
find "$ROOT" -name Info.plist -not -path '*/build/*' -print0 \
  | xargs -0 grep -l 'UIRequiresFullScreen' 2>/dev/null | sed 's|^|[full-screen-key] |'
exit 0
```

What each label means, in Apple's terms:

| Label | Why it matters on Duo | Fix lives in |
|---|---|---|
| `main-screen` | The app's size changes on every fold and rarely matches the screen. `UIScreen.main` is deprecated since iOS 26. | App Resizability skill, `duo-layout` |
| `orientation` | Orientation doesn't tell you the app's shape. The inner display ignores supported orientations. | App Resizability skill, `duo-layout` |
| `idiom` | An iPhone app can now have any mix of size classes. Regular width is not iPad. | App Resizability skill, `duo-layout` |
| `window-frame` | Windows come from a scene: `UIWindow(windowScene:)`. | App Resizability skill |
| `fixed-size` | Checks against known iPhone sizes never match Duo. | `duo-layout` |
| `fill-media` | Aspect fill can crop the subject on the wide inner display. Pick fill or fit by size class or aspect ratio. | `duo-layout` |
| `full-screen-key` | Doesn't stop resizing; deprecated in iOS 26. | `duo-layout` |

The usual swaps, for reference when you report a finding. In UIKit:

```swift
import UIKit

final class GalleryViewController: UIViewController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Not UIScreen.main.bounds: size from the view, and re-read it on every layout pass.
        let available = view.bounds.inset(by: view.safeAreaInsets)
        // Not UIScreen.main.scale: scale comes from the trait collection.
        let scale = traitCollection.displayScale
        // Wider than tall? Compare the space you have, not the device orientation.
        let isWide = available.width > available.height
        layoutTiles(in: available, scale: scale, wide: isWide)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Work that must run when the size changes, such as a fold or unfold.
    }

    private func layoutTiles(in rect: CGRect, scale: CGFloat, wide: Bool) {}

    private func currentScreen() -> UIScreen? {
        // Don't store a UIScreen. Ask the window scene when you need it.
        view.window?.windowScene?.screen
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        // Not UIWindow(frame: UIScreen.main.bounds).
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = GalleryViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}
```

In SwiftUI:

```swift
import SwiftUI

struct PhotoGrid: View {
    // Scale comes from the environment, not UIScreen.main.scale.
    @Environment(\.displayScale) private var displayScale
    @Environment(\.horizontalSizeClass) private var widthClass
    @State private var width: CGFloat = 0

    var body: some View {
        // Pick columns by size class, never by idiom.
        let columns = widthClass == .regular ? 4 : 2
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns)) {
            ForEach(0..<20, id: \.self) { index in
                Text("\(index) @\(Int(displayScale))x")
            }
        }
        // Not UIScreen.main.bounds: read the space you have, and keep reading it.
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            width = newWidth
        }
    }
}
```

Both follow Apple's [prepare page](https://developer.apple.com/iphone-duo/prepare/) and [Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/). They typecheck against the iOS 27.1 SDK at iOS 17.0 and 27.1 targets.

## 3. Install, launch and log

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer
APP="$TMPDIR/duo-first-pass/Build/Products/Debug-iphonesimulator/<App>.app"
BUNDLE=$(plutil -extract CFBundleIdentifier raw "$APP/Info.plist")
xcrun simctl boot "iPhone Duo" 2>/dev/null     # "Unable to boot device in current state: Booted" is fine
xcrun simctl install booted "$APP"
xcrun simctl launch --terminate-running-process \
  --stderr="$HOME/Library/Caches/duo-first-pass.log" booted "$BUNDLE"
```

- `--stderr=` writes the app's standard error to a file and returns at once, so you can read the log while the user changes poses.
- Keep that file in the home folder. *Measured:* with `--stderr` pointing into `$TMPDIR` or `/tmp`, no file appeared; `~/Library/Caches` and a folder under `~/Documents` worked. We didn't find out why.
- Ask the user to open Device Hub if it isn't on screen. It ships inside Xcode 27.1 at `/Applications/Xcode-27.1.app/Contents/Applications/DeviceHub.app`.
- The first simulator launch with Xcode 27.1 can take several minutes, and most app extensions can't run in the Duo simulator ([Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)).

### Optional: a debug logger

The agent can't see the simulator move. A logger prints the size, both safe-area sides, the size classes and the hinge on every change, so you can tell what each pose did without guessing. Add it only if the user agrees, attach it once at the root, and delete it when the pass is done.

SwiftUI. Attach with `.duoFirstPassLog()` on the root view:

```swift
import SwiftUI

#if DEBUG
func duoLog(_ message: String) {
    // stderr is unbuffered, so lines show up at once in `simctl launch --stderr=`.
    FileHandle.standardError.write(Data(("DUO " + message + "\n").utf8))
}

// `nonisolated` keeps this working in targets that default to MainActor isolation.
nonisolated struct DuoFirstPassSize: Equatable, Sendable {
    var width: Int
    var height: Int
    var leading: Int
    var trailing: Int
}

struct DuoFirstPassLog: ViewModifier {
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.verticalSizeClass) private var heightClass

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: DuoFirstPassSize.self) { proxy in
                DuoFirstPassSize(
                    width: Int(proxy.size.width),
                    height: Int(proxy.size.height),
                    leading: Int(proxy.safeAreaInsets.leading),
                    trailing: Int(proxy.safeAreaInsets.trailing)
                )
            } action: { space in
                duoLog("size \(space.width)x\(space.height) pt, "
                    + "safe leading \(space.leading) trailing \(space.trailing), "
                    + "width \(name(widthClass)), height \(name(heightClass))")
            }
            .modifier(DuoHingeLog())
    }

    private func name(_ sizeClass: UserInterfaceSizeClass?) -> String {
        switch sizeClass {
        case .compact: "compact"
        case .regular: "regular"
        default: "unknown"
        }
    }
}

struct DuoHingeLog: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, newContext in
                guard let hinge = newContext.hinge else {
                    duoLog("hinge none")
                    return
                }
                let status = switch hinge.status {
                case .closed: "closed"
                case .partiallyOpen: "partiallyOpen"
                case .fullyOpen: "fullyOpen"
                default: "other"
                }
                duoLog("hinge \(status) \(Int(hinge.angle.degrees)) deg")
            }
        } else {
            content
        }
    }
}
#endif

extension View {
    /// Logs size, safe-area sides, size classes and hinge status in Debug builds.
    func duoFirstPassLog() -> some View {
        #if DEBUG
        modifier(DuoFirstPassLog())
        #else
        self
        #endif
    }
}
```

UIKit. Call it from the root view controller:

```swift
import UIKit

#if DEBUG
enum DuoFirstPass {
    static func log(_ message: String) {
        FileHandle.standardError.write(Data(("DUO " + message + "\n").utf8))
    }

    @MainActor static func logLayout(of view: UIView) {
        let size = view.bounds.size
        let insets = view.safeAreaInsets
        let traits = view.traitCollection
        log("size \(Int(size.width))x\(Int(size.height)) pt, "
            + "safe left \(Int(insets.left)) right \(Int(insets.right)), "
            + "width \(name(traits.horizontalSizeClass)), height \(name(traits.verticalSizeClass))")
    }

    @MainActor static func watchHinge(on view: UIView) {
        guard #available(iOS 27.1, *) else { return }
        let interaction = UIHingeInteraction { _, update in
            guard let hinge = update.hinge else {
                log("hinge none")
                return
            }
            let status = switch hinge.status {
            case .unknown: "unknown"
            case .closed: "closed"
            case .partiallyOpen: "partiallyOpen"
            case .fullyOpen: "fullyOpen"
            @unknown default: "other"
            }
            // UIKit reports the angle in radians.
            log("hinge \(status) \(Int(hinge.angle * 180 / .pi)) deg")
        }
        view.addInteraction(interaction)
    }

    private static func name(_ sizeClass: UIUserInterfaceSizeClass) -> String {
        switch sizeClass {
        case .compact: "compact"
        case .regular: "regular"
        case .unspecified: "unspecified"
        @unknown default: "other"
        }
    }
}
#endif

// In the root view controller:
final class RootViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        #if DEBUG
        DuoFirstPass.watchHinge(on: view)
        #endif
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        #if DEBUG
        DuoFirstPass.logLayout(of: view)
        #endif
    }
}
```

Read the log with `grep '^DUO' "$HOME/Library/Caches/duo-first-pass.log"`. *Measured* with the SwiftUI logger, phone fully open, held wide:

```text
DUO size 867x635 pt, safe leading 0 trailing 84, width regular, height regular
DUO hinge fullyOpen 180 deg
```

The root view gets 867 × 635 pt inside the safe area. The safe area is 0 pt on the leading side and 84 pt on the trailing side, where the status bar sits; the full window is 951 × 669 pt ([device facts](https://github.com/Kimeur/duology/blob/main/reference/device-facts.md)). That is the asymmetry Apple warns about: never assume opposite insets match. The hinge APIs are for logging and effects here. Layout comes from size classes, safe areas and reserved regions (`duo-layout`).

## 4. Check open, then closed

Screenshot both displays after each pose change:

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer
xcrun simctl io booted screenshot --display=primary   "$TMPDIR/duo-outer.png"   # outer display
xcrun simctl io booted screenshot --display=primary-1 "$TMPDIR/duo-inner.png"   # inner display
```

- *Measured:* with the phone open, the outer screenshot came out solid black and the inner one showed the app. We assume the reverse when closed (unverified).
- *Measured:* screenshots follow the current orientation, so the sizes can swap (2853 × 2007 instead of 2007 × 2853).
- `simctl` can't change the pose (*measured*). Ask the user to click the buttons under the bezel in Device Hub: **Closed**, **Partially Open**, **Open**. Option-drag the slider below the bezel for any angle ([Device Hub article](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)). If the user asks you to script it and has given Accessibility permission to the app that runs you, `duo-pose set <closed|open|book|tabletop>` from [`duo-pose-matrix`](https://github.com/Kimeur/duology/blob/main/plugins/duology-ship/skills/duo-pose-matrix/SKILL.md) presses the same buttons. Check that no UI tests share the simulator first.
- Device Hub can't send two-finger touches (Xcode 27 known issue). Leave pinch and rotate gestures for a real device.
- When Xcode's agent connection is set up (`duo-setup`), Apple's `device-interaction` skill can read the UI tree, take screenshots and tap through Xcode after each pose change ([routing.md](routing.md#apples-skills-in-xcode-271)). We haven't run it in a first pass (unverified). Its text says nothing about poses, so the user still clicks in Device Hub.

The order that fits five minutes:

1. **Open** (often the current pose). Screenshot. Scroll a list and type in a field, so you can check later that they survive.
2. Ask for **Closed**. Screenshot. Check the scroll position and the typed text.
3. Ask for **Partially Open**, if time allows. Screenshot. Look at the middle of the inner display.
4. Ask for **Open** again. Screenshot.

What to look for:

| Pose | Look for | Load |
|---|---|---|
| Open | Empty space around a centred window (old SDK); stretched single column; content under the status bar on the right edge; cropped hero media | `duo-layout`, `duo-patterns` |
| Closed | Bars on the side, missing toolbar items, titles cut off; content under the camera | `duo-navigation`, `duo-layout` |
| Partially open | Buttons, text fields or labels in the fold | `duo-layout` |
| Any change | Lost scroll position, typed text, selection, playback, or a jump back to the root screen | `duo-continuity` |
| Any | A screen you'd design differently for the big display | `duo-patterns`, `duo-design-review` |

For screenshots of every pose Device Hub can set (closed, open, partly folded like a book, propped on a table), use [`duo-pose-matrix`](https://github.com/Kimeur/duology/blob/main/plugins/duology-ship/skills/duo-pose-matrix/SKILL.md) or `/duo-poses` (`duology-ship`). It doesn't cover Split View or standing on its edges. For Split View, Tech Talk [111461](https://developer.apple.com/videos/play/tech-talks/111461/) shows how to test it: drag the app by its home indicator to one side of the inner display, then to the other.

## Report

Write this in chat. Keep each line short. Mark anything you didn't check.

```text
iPhone Duo first pass: <App name>
Stack:            SwiftUI app | SwiftUI with UIKit parts | UIKit app | UIKit with SwiftUI screens
Ships with:       Xcode <x> / iOS <x> SDK (source: CI pin | DTSDKName | user) -> on Duo: <row from the SDK table>
Scene life cycle: yes | NO (blocker: the app won't launch when built with the iOS 27 SDK)
Deployment target: iOS <x> (gate iOS 27.1 APIs: yes | no)   Catalyst: yes | no
Xcode 27.1 build: succeeded | failed with <n> errors (first three: ...)
duo-lint:         <n> findings (top five: file:line rule)
Open:             <what you saw>
Closed:           <what you saw>
Partially open:   <what you saw | not checked>
State kept across fold: scroll yes|no, text yes|no, navigation yes|no
Next:             1. <skill> for <problem>  2. ...  3. ...
Apple's App Resizability skill: offered | used | not available
```

## Clean up

- Delete the debug logger and its call sites.
- Leave the simulator booted; other work may be using it.
- Remove the test install if the user wants a clean simulator: `DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcrun simctl uninstall booted <bundle id>`. Use the bundle ID from section 3; `$BUNDLE` is gone if the shell changed.
- The build output in `$TMPDIR/duo-first-pass` can stay; it isn't in the repo. Delete `~/Library/Caches/duo-first-pass.log` when the report is written.
