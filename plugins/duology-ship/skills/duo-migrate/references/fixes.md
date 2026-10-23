# Fixes for each pattern

Before-and-after code for the patterns in `SKILL.md`, Step 4. Every Swift block here typechecks against the iOS 27.1 simulator SDK with deployment targets iOS 16.0 and 27.1 (23 October 2026). The rule behind all of them: read the size of the view or window you are in, and read it again when it changes. A fold changes it while the app runs.

## Adopt the scene life cycle

For a UIKit app with no scenes (`SKILL.md`, Step 2). The window moves from the app delegate to a scene delegate. *Measured:* this shape launched and kept running on the iPhone Duo simulator; without it, the same app crashed at launch ([evidence.md](evidence.md)).

```swift
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    // Needed only when the Info.plist's scene manifest doesn't name the delegate class.
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        // What didFinishLaunchingWithOptions built before, on a window tied to this scene.
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: ExpensesViewController())
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Work that lived in applicationDidEnterBackground(_:): save drafts, stop timers.
    }
}

final class ExpensesViewController: UIViewController {}
```

The manifest, when the delegate is named there instead (with Xcode's generated Info.plist, add these keys to the target's Info tab):

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
    <key>UISceneConfigurations</key>
    <dict>
        <key>UIWindowSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneConfigurationName</key>
                <string>Default</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>
```

Where the app delegate's life-cycle methods go ([Apple's guide](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle)):

| App delegate (no longer called) | Scene delegate |
|---|---|
| `applicationDidBecomeActive(_:)` | `sceneDidBecomeActive(_:)` |
| `applicationWillResignActive(_:)` | `sceneWillResignActive(_:)` |
| `applicationDidEnterBackground(_:)` | `sceneDidEnterBackground(_:)` |
| `applicationWillEnterForeground(_:)` | `sceneWillEnterForeground(_:)` |

Each scene delegate hears only its own scene. For "is any part of the app in the foreground", observe `UIApplication.willEnterForegroundNotification` and its siblings instead. `UIApplicationSupportsMultipleScenes` stays `false` unless the app is ready for several windows (`duo-scenes`).

## Size from the window, not the screen

`UIScreen.main` (DUO001) describes the display, not the app's window, and on iPhone Duo the window changes size with every fold.

```swift
import UIKit

final class GridViewController: UIViewController {
    let layout = UICollectionViewFlowLayout()

    // Before: let side = UIScreen.main.bounds.width / 3, read once.
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let side = floor(view.bounds.width / 3)   // this window, now; runs again after each fold
        layout.itemSize = CGSize(width: side, height: side)
    }

    func pixelSize(points: CGFloat) -> CGFloat {
        points * traitCollection.displayScale    // instead of UIScreen.main.scale
    }

    var currentScreen: UIScreen? {
        view.window?.windowScene?.screen         // only when you need the screen itself
    }
}
```

```swift
import SwiftUI

struct CoverHeader: View {
    var body: some View {
        // Before: .frame(height: UIScreen.main.bounds.height * 0.3)
        GeometryReader { proxy in
            Color.indigo
                .frame(height: proxy.size.height * 0.3)
        }
    }
}
```

## Shape, not orientation

`UIDevice.current.orientation`, `statusBarOrientation` and `interfaceOrientation` (DUO002, DUO003) don't say what shape the app has: the closed phone held sideways and the open phone held upright both differ from what orientation suggests. Compare width and height of the space you have.

```swift
import UIKit

final class GalleryViewController: UIViewController {
    // Before: let columns = UIDevice.current.orientation.isLandscape ? 5 : 3
    var columns: Int {
        view.bounds.width > view.bounds.height ? 4 : 2
    }
}
```

Use even column counts on the open phone so the fold falls between columns (`duo-layout`).

## Space, not device

`userInterfaceIdiom == .pad` (DUO004), "regular width means iPad" (DUO005) and known device sizes such as `<= 667` (DUO006, DUO007, DUO009) all break on a phone that reports regular width when open. Choose the layout from the size class or the space, and update it when either changes.

```swift
import UIKit

final class RootViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        updateLayout()
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (self: Self, _: UITraitCollection) in
                self.updateLayout()
            }
        }
        // Below iOS 17, call updateLayout() from traitCollectionDidChange(_:) instead.
    }

    func updateLayout() {
        // Before: if UIDevice.current.userInterfaceIdiom == .pad { … }
        let twoPanes = traitCollection.horizontalSizeClass == .regular
        // Show the list and the detail side by side, or one at a time.
        _ = twoPanes
    }
}
```

```swift
import SwiftUI

struct TotalsRow: View {
    let total: String
    let average: String

    var body: some View {
        // Before: if geometry.size.height <= 667 { compact } else { regular }
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 24) { Text(total); Text(average) }
            VStack(alignment: .leading) { Text(total); Text(average) }
        }
    }
}
```

## UIRequiresFullScreen

The key (DUO008) no longer keeps the app from resizing on iPhone Duo: the app still resizes when the phone opens or closes ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)), and Apple deprecated it in iOS 26 ([TN3192](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key)). Remove it from the Info.plist or the `INFOPLIST_KEY_UIRequiresFullScreen` build setting once the layout resizes; duo-lint's DUO008 entry lists the alternative key. Then test Split View on the inner display (`duo-scenes`).

## Full-bleed media

Hero images and video that fill their frame (`.scaleAspectFill`, `contentMode: .fill`) crop more on the wide inner display, sometimes the part that matters ([prepare page](https://developer.apple.com/iphone-duo/prepare/)). duo-lint doesn't flag this; search for both spellings. Pick fill or fit from the shapes. The 1.5 threshold below is a starting point, not Apple's number: past it, fill would cut off a third or more of the image.

```swift
import UIKit

func contentMode(for imageSize: CGSize, in bounds: CGSize) -> UIView.ContentMode {
    let viewAspect = bounds.width / max(bounds.height, 1)
    let imageAspect = imageSize.width / max(imageSize.height, 1)
    let mismatch = max(viewAspect, imageAspect) / min(viewAspect, imageAspect)
    return mismatch > 1.5 ? .scaleAspectFit : .scaleAspectFill
}
```

```swift
import SwiftUI

struct HeroImage: View {
    let image: Image
    let imageAspect: CGFloat   // the asset's width divided by its height

    var body: some View {
        GeometryReader { proxy in
            let viewAspect = proxy.size.width / max(proxy.size.height, 1)
            let mismatch = max(viewAspect, imageAspect) / min(viewAspect, imageAspect)
            image
                .resizable()
                .aspectRatio(contentMode: mismatch > 1.5 ? .fit : .fill)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }
}
```

For video, the same choice applies to `AVPlayerLayer.videoGravity` (`.resizeAspect` or `.resizeAspectFill`); `duo-media` covers players.
