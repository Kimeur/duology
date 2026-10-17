# duo-lint rules

Every rule, what it flags, why, and how to fix it. Each fix shows the bad code and the code to write instead. All Swift on this page typechecks against the iOS 27.1 SDK (Xcode 27.1, 27A9275). The "bad" examples compile too, with deprecation warnings where the SDK has them.

Most rules come from one Apple page: [Three steps to make your app shine on iPhone Duo](https://developer.apple.com/iphone-duo/prepare/) (Step 2, "Fix patterns"). The others cite their own source.

| Rule | Name | Severity | Flags |
|---|---|---|---|
| [DUO001](#duo001-main-screen) | `main-screen` | error | `UIScreen.main`, `UIScreen.screens`, `.main` where Swift infers `UIScreen` |
| [DUO002](#duo002-device-orientation) | `device-orientation` | warning | `UIDevice.current.orientation`, its notification, `effectiveGeometry.interfaceOrientation`, any `interfaceOrientation` read DUO003 doesn't claim |
| [DUO003](#duo003-deprecated-interface-orientation) | `deprecated-interface-orientation` | error | `statusBarOrientation`, `interfaceOrientation` on a `UIWindowScene` or view controller the code shows |
| [DUO004](#duo004-idiom-layout) | `idiom-layout` | warning | `userInterfaceIdiom` compared with `.pad` or `.phone` |
| [DUO005](#duo005-regular-width-is-ipad) | `regular-width-is-ipad` | warning | `horizontalSizeClass == .regular` next to "iPad" |
| [DUO006](#duo006-device-size-literal) | `device-size-literal` | warning | `bounds.height == 844` and lists of device sizes |
| [DUO007](#duo007-fixed-width) | `fixed-width` | warning | `.frame(width: 390)`, width constraints of 320 pt or more |
| [DUO008](#duo008-requires-full-screen) | `requires-full-screen` | warning | `UIRequiresFullScreen` set to true |
| [DUO009](#duo009-geometry-device-size) | `geometry-device-size` | warning | `proxy.size.width == 393` |

**Errors** use APIs the SDK already deprecates and that Apple tells you to remove. **Warnings** are patterns that are almost always wrong on iPhone Duo but have rare valid uses.

The linter reads code, not comments or string literals. Swift string interpolation (`"\(UIScreen.main.scale)"`) counts as code. Code inside `#if os(macOS)`, `os(watchOS)`, `os(tvOS)`, `os(visionOS)`, `targetEnvironment(macCatalyst)` or `canImport(AppKit)`, and in the `#else` of `#if os(iOS)`, is skipped, because it never runs on iPhone Duo.

duo-lint reads text, not types. Where a rule depends on a type, such as DUO003, it says below how it decides.

In folders it skips build output and dependencies (`build/`, `DerivedData/`, `.build/`, `Pods/`, `Carthage/`, `SourcePackages/`, `node_modules/`), the agent folders `.claude/` and `.agents/`, and its own `tests/fixtures/` wherever the skill is installed. Those fixtures are bad code on purpose. A folder you name on the command line is always checked.

---

## DUO001 main-screen

**Severity:** error.

**Flags:** `UIScreen.main`, `UIScreen.screens`, and in Objective-C `[UIScreen mainScreen]`, `UIScreen.mainScreen` and `[UIScreen screens]`. In Swift it also flags `.main` where Swift infers `UIScreen`:

- a `UIScreen` declaration or default value: `let screen: UIScreen = .main`, `func f(screen: UIScreen = .main)`;
- a `UIScreen` getter or function that returns `.main`: `var screen: UIScreen { .main }`;
- `?? .main` after a name that ends in `screen`: `scene?.screen ?? .main`;
- an argument labelled `screen:` with `.main`: `Observer(screen: .main)`.

Other `.main` values, such as `DispatchQueue.main`, `RunLoop.main` or `queue ?? .main`, are fine. A `.main` with no `UIScreen` or `screen` on the line or in the getter above it is missed.

**Why:** your app's window changes size every time the phone folds or unfolds, and it is often not the size of the screen. iPhone Duo also has two displays, so "the main screen" doesn't say which one you mean. Apple's [prepare page](https://developer.apple.com/iphone-duo/prepare/) says to search for `UIScreen.main` and replace every use. The iOS 27.1 SDK marks `UIScreen.main` deprecated since iOS 26.0 and `UIScreen.screens` since iOS 16.0 ([UIScreen.main](https://developer.apple.com/documentation/uikit/uiscreen/main)). `UIWindow(frame:)` is deprecated in the iOS 27.1 SDK too; its message points to `init(windowScene:)`.

**Fix:** size from the view or window, and re-read the size whenever it changes. A fold can resize the app in the middle of a session, so a size read once at launch goes stale.

Bad:

```swift
import UIKit

final class GalleryViewController: UIViewController {
    private let tile = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        let side = UIScreen.main.bounds.width / 2
        tile.frame = CGRect(x: 0, y: 0, width: side, height: side)
        view.addSubview(tile)
    }
}
```

Good (UIKit): do size-dependent layout in `viewDidLayoutSubviews()` and read scale from the trait collection.

```swift
import UIKit

final class GalleryViewController: UIViewController {
    private let tile = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tile)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let side = view.bounds.width / 2
        tile.frame = CGRect(x: 0, y: 0, width: side, height: side)
    }

    func pixels(for points: CGFloat) -> CGFloat {
        points * traitCollection.displayScale
    }
}
```

Good (SwiftUI): read the size with `GeometryReader` or `onGeometryChange(for:of:action:)`, and the scale with `@Environment(\.displayScale)`.

```swift
import SwiftUI

struct ThumbnailBadge: View {
    @Environment(\.displayScale) private var displayScale
    @State private var width: CGFloat = 0

    var body: some View {
        Color.gray
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
            .overlay(Text("\(Int(width * displayScale)) px wide"))
    }
}
```

Good (windows): create the window from its scene.

```swift
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}
```

If you need the screen itself, read `view.window?.windowScene?.screen` at the moment you use it. Don't keep a `UIScreen` in a property. duo-lint can't see a stored screen, so check for it by hand.

---

## DUO002 device-orientation

**Severity:** warning.

**Flags:** `UIDevice.current.orientation`, `UIDevice.orientationDidChangeNotification`, `beginGeneratingDeviceOrientationNotifications()`, their Objective-C forms, and every `interfaceOrientation` read that [DUO003](#duo003-deprecated-interface-orientation) doesn't claim. That covers a scene geometry read through any name (`scene.effectiveGeometry.interfaceOrientation`, `let g = scene.effectiveGeometry` then `g.interfaceOrientation`, a `UIWindowScene.Geometry` parameter) and a read whose owner the code doesn't show (`scenes.first?.interfaceOrientation`).

**Why:** on iPhone Duo, the way the phone is held doesn't tell you the shape of your window. Apple's [prepare page](https://developer.apple.com/iphone-duo/prepare/) lists these properties, including `windowScene.effectiveGeometry.interfaceOrientation`, and says to remove layout logic that depends on them. The inner display also ignores the orientations your app supports ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)). This is a warning, not an error, because none of these is deprecated and a few uses are not layout.

**Fix:** compare the width and height of the space you have.

Bad:

```swift
import SwiftUI
import UIKit

struct PlayerScreen: View {
    @State private var isLandscape = UIDevice.current.orientation.isLandscape

    var body: some View {
        Text(isLandscape ? "Side by side" : "Stacked")
            .onReceive(NotificationCenter.default.publisher(
                for: UIDevice.orientationDidChangeNotification)) { _ in
                isLandscape = UIDevice.current.orientation.isLandscape
            }
    }
}
```

Good (SwiftUI):

```swift
import SwiftUI

struct PlayerScreen: View {
    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height
            let layout = isWide ? AnyLayout(HStackLayout()) : AnyLayout(VStackLayout())
            layout {
                Color.black
                Text("Up next")
            }
        }
    }
}
```

Good (UIKit):

```swift
import UIKit

final class PlayerViewController: UIViewController {
    private let stack = UIStackView()

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        stack.axis = view.bounds.width > view.bounds.height ? .horizontal : .vertical
    }
}
```

Camera apps: don't rotate the preview from the device orientation. Use `AVCaptureDevice.RotationCoordinator`. Its `videoRotationAngleForHorizonLevelPreview` supports key-value observing, so observe it to keep the preview level ([doc](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator/videorotationangleforhorizonlevelpreview)).

```swift
import AVFoundation

final class PreviewRotation {
    private var coordinator: AVCaptureDevice.RotationCoordinator?

    func start(device: AVCaptureDevice, previewLayer: AVCaptureVideoPreviewLayer) {
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device,
                                                              previewLayer: previewLayer)
        previewLayer.connection?.videoRotationAngle =
            coordinator.videoRotationAngleForHorizonLevelPreview
        self.coordinator = coordinator
    }
}
```

---

## DUO003 deprecated-interface-orientation

**Severity:** error.

**Flags:** `statusBarOrientation`, and `interfaceOrientation` read from a `UIWindowScene` or a view controller.

**How it decides:** duo-lint reads text, not types. It reports DUO003 only when the same file shows that the owner is a `UIWindowScene` or a view controller:

- a name declared with the type: `windowScene: UIWindowScene`, `vc: UIViewController`, or any type whose name ends in `Controller` (in Objective-C, `UIWindowScene *scene`);
- a cast: `(scene as? UIWindowScene)?.interfaceOrientation`, `guard let ws = scene as? UIWindowScene`;
- a name assigned from one of those, or from `.windowScene`: `let ws = view.window?.windowScene`;
- a chain that ends in `.windowScene`, or in a property whose name ends in `ViewController`;
- `self.interfaceOrientation` or a bare `interfaceOrientation` in a Swift file that subclasses or extends a `…ViewController`, and `[self interfaceOrientation]` in an Objective-C `@implementation` of one. If the file declares its own `interfaceOrientation`, those reads are DUO002.

For a name, it uses the nearest declaration above the read in the same file, or the first one below it (a property declared after the method that uses it). It doesn't follow scopes, closures or other files. Every other read is DUO002, so a deprecated read it can't place shows up as a warning, not an error. A custom type whose name ends in `Controller` and that has its own `interfaceOrientation` property gets DUO003 by mistake; silence it with a reason.

**Why:** the same reason as DUO002, and these APIs are deprecated in the iOS 27.1 SDK: `UIApplication.statusBarOrientation` since iOS 13.0, `UIWindowScene.interfaceOrientation` since iOS 26.0, and `UIViewController.interfaceOrientation` since iOS 8.0. See the [prepare page](https://developer.apple.com/iphone-duo/prepare/) and [statusBarOrientation](https://developer.apple.com/documentation/uikit/uiapplication/statusbarorientation).

**Fix:** for layout, compare width and height, as in DUO002. If you need the orientation for something that is not layout, read `windowScene.effectiveGeometry.interfaceOrientation`. duo-lint still warns about that read (DUO002), so add a disable comment that says why.

Bad:

```swift
import UIKit

final class ReaderViewController: UIViewController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let pages = UIApplication.shared.statusBarOrientation.isLandscape ? 2 : 1
        let wide = view.window?.windowScene?.interfaceOrientation.isLandscape ?? false
        print(pages, wide)
    }
}
```

Good:

```swift
import UIKit

final class ReaderViewController: UIViewController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let pages = view.bounds.width > view.bounds.height ? 2 : 1
        print(pages)
    }

    func orientationForAnalytics() -> UIInterfaceOrientation? {
        // duo-lint:disable-next-line DUO002 -- analytics only, not layout
        view.window?.windowScene?.effectiveGeometry.interfaceOrientation
    }
}
```

---

## DUO004 idiom-layout

**Severity:** warning.

**Flags:** `userInterfaceIdiom` (on `UIDevice` or a trait collection) or `UI_USER_INTERFACE_IDIOM()` compared with `.pad` or `.phone` (also written `UIUserInterfaceIdiom.pad`, or `UIUserInterfaceIdiomPad` in Objective-C):

- `==` or `!=`, with the idiom on either side;
- `if case .pad = …`, also after `guard` or `while`;
- `[.pad, .mac].contains(…)`;
- a `switch` on the idiom that has a `case .pad` or `case .phone`.

It follows a variable that holds the idiom, such as `let idiom = UIDevice.current.userInterfaceIdiom`, and any name typed `UIUserInterfaceIdiom`.

It doesn't flag reading or passing the idiom (`print(idiom)`, `UITraitCollection(userInterfaceIdiom: .pad)`, `traitOverrides.userInterfaceIdiom = .pad`), declarations, comparisons with other idioms (`.mac`, `.vision`, `.tv`, `.carPlay`), or anything inside `supportedInterfaceOrientations` and `application(_:supportedInterfaceOrientationsFor:)`. Those pick the orientations the app supports, not a layout.

**Why:** Apple's [Duo overview](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo) says not to use `userInterfaceIdiom` for layout decisions, and the [prepare page](https://developer.apple.com/iphone-duo/prepare/) says to search for `userInterfaceIdiom == .phone` and `== .pad`. *Measured:* a process run inside the iPhone Duo simulator (iOS 27.1) reports the `.phone` idiom, and the simulator's device profile lists only the iPhone product family. So an iPad layout behind `== .pad` never shows on the 7.6 in inner display, and a phone layout behind `== .phone` gets stretched across it.

**Fix:** choose the layout by size class or by the space you have. System containers already do this.

Bad:

```swift
import SwiftUI
import UIKit

struct LibraryView: View {
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView {
                List { Text("Albums") }
            } detail: {
                Text("Pick an album")
            }
        } else {
            NavigationStack {
                List { Text("Albums") }
            }
        }
    }
}
```

Good: `NavigationSplitView` shows one column in compact width and both columns in regular width, on any device.

```swift
import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationSplitView {
            List { Text("Albums") }
        } detail: {
            Text("Pick an album")
        }
    }
}
```

Good (UIKit): read the size class in a method that has [automatic trait tracking](https://developer.apple.com/documentation/uikit/automatic-trait-tracking), such as `viewWillLayoutSubviews()`. UIKit calls it again when the size class changes.

```swift
import UIKit

final class LibraryViewController: UIViewController {
    private let stack = UIStackView()

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        stack.axis = traitCollection.horizontalSizeClass == .regular ? .horizontal : .vertical
    }
}
```

Keep idiom checks for behaviour that truly differs by device type, and add a disable comment with the reason.

---

## DUO005 regular-width-is-ipad

**Severity:** warning. Heuristic.

**Flags:** `horizontalSizeClass` (or a SwiftUI `@Environment(\.horizontalSizeClass)` variable) compared with `.regular`, when "iPad" or "tablet" appears within two lines in a comment, a name or a string. The same with `.compact` next to "iPhone". Also `case .regular:` in a `switch` on the size class, next to "iPad".

**Why:** an iPhone can now have any mix of size classes. iPhone Duo's outer display is compact width and its inner display is regular width ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)). Apple's [prepare page](https://developer.apple.com/iphone-duo/prepare/) warns that an "iPad-only" layout behind `horizontalSizeClass == .regular` now runs on iPhone too. That is fine if you meant "wide". It is a bug if the code assumes iPad things, such as iPad-only APIs, iPad copy or iPad assets.

**Fix:** name the layout after the space, and make sure it works on an iPhone-sized phone that opens wide.

Bad:

```swift
import SwiftUI

struct SettingsScreen: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    var body: some View {
        Text(isIPad ? "iPad settings" : "iPhone settings")
    }
}
```

Good:

```swift
import SwiftUI

struct SettingsScreen: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isWide: Bool { sizeClass == .regular }

    var body: some View {
        let layout = isWide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 24))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        layout {
            Text("Account")
            Text("Notifications")
        }
    }
}
```

---

## DUO006 device-size-literal

**Severity:** warning.

**Flags:**

- a comparison (`==`, `!=`, `<`, `>`, `<=`, `>=`) between a size and a known device dimension in points;
- a list of two or more device dimensions, such as `[568, 667, 736].contains(height)`;
- `case 568, 667:` in a `switch` on a size;
- `CGSize` or `CGRect` (and `CGSizeMake`, `CGRectMake`) with a device width and a device height;
- native pixel sizes, such as `nativeBounds.height == 2436`, on lines that read `nativeBounds` or `nativeScale`. A line that only mentions pixels, such as `imagePixelWidth == 1920`, doesn't count.

The device dimensions are the point widths and heights of iPhone and iPad models, plus iPhone Duo window sizes: 466 × 678 (outer display, derived) and 951 × 669 (inner display fully open, measured). See [device-facts.md](https://github.com/Kimeur/duology/blob/main/reference/device-facts.md). `320`, `768` and `1024` are also common image sizes and breakpoints, so they count only when the line names the screen, window, view, bounds, scene, safe area, geometry or proxy. The full lists are at the top of `scripts/duo-lint.py`. Previews (`#Preview`, `PreviewProvider`) are skipped.

**Why:** Apple's [prepare page](https://developer.apple.com/iphone-duo/prepare/) says comparisons such as `bounds.height == 844`, and lists of known iPhone sizes, won't match iPhone Duo. Its windows change size with every fold, rotation and Split View.

**Fix:** delete the size check. Pick the layout by size class, by `ViewThatFits`, or by comparing width with height.

Bad:

```swift
import UIKit

final class HeaderViewController: UIViewController {
    private let title2 = UILabel()

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        title2.isHidden = view.bounds.height <= 667
    }
}
```

Good (UIKit): ask for the trait that describes the space.

```swift
import UIKit

final class HeaderViewController: UIViewController {
    private let title2 = UILabel()

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        title2.isHidden = traitCollection.verticalSizeClass == .compact
    }
}
```

Good (SwiftUI): let `ViewThatFits` pick the first child that fits.

```swift
import SwiftUI

struct Header: View {
    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack {
                Image(systemName: "sparkles")
                Text("Welcome back")
                Text("Here is what changed")
            }
            Text("Welcome back")
        }
    }
}
```

---

## DUO007 fixed-width

**Severity:** warning.

**Flags:** `.frame(width:)` or `.frame(minWidth:)` with a number of 320 or more, on any line of a multi-line `.frame(` call; `widthAnchor.constraint(equalToConstant:)` and `greaterThanOrEqualToConstant:` with 320 or more, and the Objective-C forms. It does not flag `maxWidth`, `idealWidth`, widths below 320 (icons, buttons, thumbnails), widths you compute, or previews.

**Why:** the HIG page for iPhone Duo tells you to avoid fixed widths and anything tied to one display ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)). Your app can be the full outer display, the full inner display, one half of Split View, or one half of an arrangement. A width that fits one of those can overflow another. 320 pt is duo-lint's threshold, not an Apple number.

**Fix:** cap widths instead of fixing them, and let the container decide.

Bad:

```swift
import SwiftUI

struct PromoCard: View {
    var body: some View {
        Text("Try the new editor")
            .frame(width: 390, height: 120)
            .background(.blue)
    }
}
```

Good (SwiftUI): `maxWidth` caps the card on wide windows and lets it shrink on narrow ones. `containerRelativeFrame` sizes it from the container.

```swift
import SwiftUI

struct PromoCard: View {
    var body: some View {
        Text("Try the new editor")
            .frame(maxWidth: 600)
            .frame(height: 120)
            .background(.blue)
    }
}

struct PromoStrip: View {
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(0..<6) { index in
                    Text("Card \(index)")
                        .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
            }
        }
    }
}
```

Good (UIKit): pin to the readable content guide, or use a `lessThanOrEqualToConstant` width.

```swift
import UIKit

final class FormViewController: UIViewController {
    private let card = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        let guide = view.readableContentGuide
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            card.topAnchor.constraint(equalTo: guide.topAnchor),
            card.heightAnchor.constraint(equalToConstant: 120),
        ])
    }
}
```

---

## DUO008 requires-full-screen

**Severity:** warning.

**Flags:** `UIRequiresFullScreen` set to `true` (also `UIRequiresFullScreen~ipad`) in an `Info.plist`, XML or binary, and `INFOPLIST_KEY_UIRequiresFullScreen = YES` in `.xcconfig` files and `project.pbxproj`. In folders it reads files named `Info.plist` or ending in `Info.plist`; pass other plists by name. It stays quiet when the same plist also has `UIRequiresFullScreenIgnoredStartingWithVersion`, which is Apple's migration path.

**Build setting plus Info.plist:** with `GENERATE_INFOPLIST_FILE`, Xcode merges `INFOPLIST_KEY_UIRequiresFullScreen` into the Info.plist file that `INFOPLIST_FILE` names. Xcode 27.1 has no build setting for the ignore key, so that key can only go in the file. duo-lint stays quiet about the build setting when the merged file has the ignore key:

- In `project.pbxproj`, it reads `INFOPLIST_FILE` from the same build configuration. `$(SRCROOT)`, `$(PROJECT_DIR)` and `$(SOURCE_ROOT)` stand for the folder that holds the `.xcodeproj`.
- When it can't resolve that path (an `.xcconfig` without `INFOPLIST_FILE`, other variables, a missing file), it accepts any Info.plist with the ignore key inside the same project folder, as long as the same run checks it. So `duo-lint .` from the project root sees both; `duo-lint Config/Base.xcconfig` alone still warns.

**Why:** [TN3192](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key) says the key is deprecated since iPadOS 26. From iOS 27, when you build with the iOS 27 SDK, it no longer stops your app from resizing; the system resizes the scene in discrete steps instead. Apple's Duo talk adds that an app with the key still resizes when the phone opens or closes ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)). Keeping the key only hides the work you still need to do.

**Fix:** delete the key from `Info.plist` and the "Requires Full Screen" build setting, then fix the layout with the other rules. If an older iOS version still needs the key, keep it and add `UIRequiresFullScreenIgnoredStartingWithVersion` (a string, available from iOS 26.2) with the first version that should ignore it ([doc](https://developer.apple.com/documentation/bundleresources/information-property-list/uirequiresfullscreenignoredstartingwithversion)).

Bad:

```xml
<key>UIRequiresFullScreen</key>
<true/>
```

Good, when an older iOS still needs it:

```xml
<key>UIRequiresFullScreen</key>
<true/>
<key>UIRequiresFullScreenIgnoredStartingWithVersion</key>
<string>26</string>
```

---

## DUO009 geometry-device-size

**Severity:** warning.

**Flags:** the size of a `GeometryReader` proxy compared with a device dimension, for example `proxy.size.width == 393` or `geo.size.width >= 744`. It finds proxy names from `GeometryReader { name in` and from parameters typed `GeometryProxy`. Any device dimension counts here, including 320, 768 and 1024. Breakpoints that are not device sizes, such as `proxy.size.width > 600`, are not flagged.

**Why:** the same reason as DUO006. A `GeometryReader` is the right tool, but matching its size to a phone model brings back the device assumption ([prepare page](https://developer.apple.com/iphone-duo/prepare/)).

**Fix:** compare the proxy's width with its height, or switch on the size class.

Bad:

```swift
import SwiftUI

struct PhotoGrid: View {
    var body: some View {
        GeometryReader { proxy in
            let columns = proxy.size.width >= 1024 ? 4 : 2
            Text("\(columns) columns")
        }
    }
}
```

Good: derive the column count from the width you have, and keep it even, so the grid splits cleanly at the fold ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)).

```swift
import SwiftUI

struct PhotoGrid: View {
    let minTile: CGFloat = 160

    var body: some View {
        GeometryReader { proxy in
            let fit = max(1, Int(proxy.size.width / minTile))
            let columns = fit > 1 ? fit - fit % 2 : 1
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns)) {
                ForEach(0..<24) { index in
                    Color.gray.aspectRatio(1, contentMode: .fit).overlay(Text("\(index)"))
                }
            }
        }
    }
}
```

---

## Silencing a finding

Silence a finding only when the code is not layout. Always give the reason after `--`.

```swift
import UIKit

@MainActor
func logScreenScale() {
    // duo-lint:disable-next-line DUO001 -- crash reports need the device scale
    print(UIScreen.main.scale)
}
```

| Comment | Effect |
|---|---|
| `// duo-lint:disable-next-line DUO001` | Skips DUO001 on the next line. |
| `// duo-lint:disable-line DUO001` | Skips DUO001 on the same line. |
| `// duo-lint:disable-file DUO004` | Skips DUO004 in the whole file. Put it anywhere in the file. |

- List several rules with spaces or commas: `DUO001 DUO006`.
- With no rule id, the comment skips every rule. Prefer naming the rule.
- In `Info.plist`, use an XML comment: `<!-- duo-lint:disable-next-line DUO008 -->`.
- Text in a string literal does nothing. The comment must be a real comment.

## What duo-lint doesn't catch

duo-lint reads code. It can't run your app. A clean report means none of these patterns is left. It doesn't mean the app works on iPhone Duo. It also misses:

- controls that sit in the fold (see the `duo-layout` skill: reserved regions);
- state lost when the phone folds or unfolds (see `duo-continuity`);
- a `UIScreen` kept in a property, or a size read once at launch and never again;
- device sizes behind names it can't see, such as `if h < 667` where nothing on the line says width, height, size or bounds;
- a deprecated `interfaceOrientation` read whose owner the file doesn't show: it reports DUO002 (warning) instead of DUO003;
- `UIApplication.shared.windows` or `keyWindow` bounds used as the screen size;
- full-bleed media with `.scaleAspectFill` or `.aspectRatio(contentMode: .fill)` that loses content on wider windows (the prepare page asks you to check these by hand);
- Swift regex literals that contain a quote (rare): they can confuse the comment and string scanner.

Then build with Xcode 27.1 and look at the app on the iPhone Duo simulator, closed, open and partly open.
