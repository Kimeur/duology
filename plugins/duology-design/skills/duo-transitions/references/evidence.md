# Evidence: what we measured

Every *measured* line in this skill comes from the runs below. Read the limits before you rely on them.

- **When:** 18 October 2026.
- **Tools:** Xcode 27.1 (27A9275), the iOS 27.1 simulator runtime, one shared "iPhone Duo" simulator. It started closed and in portrait each time, and we put it back that way.
- **How the poses changed:** a script pressed Device Hub's own Closed, Partially Open, Open and Rotate Right buttons through the macOS Accessibility API, as `duo-setup` describes ([Script the pose buttons](https://github.com/Kimeur/duology/blob/main/plugins/duology/skills/duo-setup/references/simulator-and-device-hub.md#script-the-pose-buttons)). It refused to start, or stopped between steps, while a UI test or another session's app was active on the simulator.
- **Device:** none. Nothing here has run on a real iPhone Duo.

## The method, and its limits

Each probe is a one-file app: a UIKit app delegate and view controller hosting a SwiftUI view. It prints one timestamped line per event.

- **UIKit:** `viewWillTransition(to:with:)` with the coordinator's `isAnimated` and `transitionDuration`; the alongside and completion blocks with `UIView.inheritedAnimationDuration`; a `registerForTraitChanges(_:handler:)` handler for the horizontal size class; `layoutSubviews` sizes; the scene delegate's connect, disconnect, resign-active and become-active callbacks.
- **SwiftUI:** `Animatable` probes. SwiftUI hands an animatable modifier every in-between value of an animated change and only the end value of one that isn't animated. So a run of values strictly between the old and new target means the change animated, and one value means it didn't. Probes sat under no modifier, under `.animation(_:value:)`, under an opt-out, and on a copy of the size class written with `withAnimation`.
- **TProbe** (runs 1 and 2) also flipped the size class from code at launch, with a plain state change, before any pose change. **TProbe2** (run 3) added rotation, scene callbacks and root identity.

What this can't tell you: anything about 120 Hz (the simulator runs at 60), how long a frame really takes on a device, what the hardware shows while the displays hand over, and whether a frame reached the screen between two log lines. Timings are from one Mac and a handful of runs.

## Does a fold relaunch or reset the app?

No, in every run.

| Run | Changes | What we saw |
|---|---|---|
| 2 (TProbe) | Open, Partially Open, Open, Closed, four rotations, Closed | One launch line. No relaunch. |
| 3 (TProbe2) | Four rotations closed, Open, four rotations open, Closed | One `scene willConnect`, one root `onAppear` (token `0773`), no `onDisappear`, no scene disconnect. After launch, no `sceneWillResignActive` or `sceneDidBecomeActive` at all. |

So a fold is a resize, as Apple says ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=142)). The scene stayed active through it.

`@Environment(\.scenePhase)` in this UIKit-hosted root read `background` at launch and never changed, even after the scene became active. Use the scene delegate, or a SwiftUI `App`, to observe phases.

## What UIKit hands you

| Change | `viewWillTransition` size | `isAnimated` | `transitionDuration` | Alongside block | Completion |
|---|---|---|---|---|---|
| Open | 466 × 678 → 951 × 669 | `false` | 0 | Inherited duration 0, bounds already 951 × 669 | 7 ms after the call |
| Close | 951 × 669 → 466 × 678 | `false` | 0 | Inherited duration 0 | 4 ms after the call |
| Rotate closed, quarter turn | 466 × 678 ↔ 678 × 466 | `true` | 0.3 | Inherited duration 0.3 | 0.33 to 0.37 s later |
| Rotate closed, half turn (upside down to landscape) | 678 × 466 → 678 × 466 | `true` | 0.6 | | |
| Rotate open, quarter turn | 951 × 669 ↔ 669 × 951 | `true` | 0.3 | Inherited duration 0.3 | 0.33 s later |
| Partially Open, and Open from partly open | no call | | | | |

- Pressing Rotate Right while closed and in landscape right turned the device to portrait upside down. The app doesn't list that orientation, so nothing happened. The next press (to landscape left) arrived as the 0.6 s half turn.
- `willTransition(to:with:)` for the trait collection came with `isAnimated` `false` on open and close.
- Order of the trait handler and `viewWillTransition(to:with:)`:

| Change | Trait handler | `viewWillTransition` | Gap |
|---|---|---|---|
| Close (run 2) | 33.958 | 33.984 | trait first, 26 ms |
| Close (run 2, restore) | 63.528 | 63.552 | trait first, 24 ms |
| Open (run 2) | 10.789 | 10.787 | size first, 2 ms |
| Open (run 2, from the sideways closed phone) | 50.874 | 50.893 | trait first, 19 ms |

## What SwiftUI hands you

"One step" means the probe logged only the end value. "Animated" means it logged a run of in-between values.

| Probe | Flip from code | Open | Close | Partially Open | Rotate |
|---|---|---|---|---|---|
| Size class or fold, no modifier | one step | one step | one step | one step | one step |
| `.animation(.linear(duration: 0.5), value:)` | animated, 30 values | animated, 27 values | animated, 29 values | animated, 30 values | animated, 30 values |
| Copy in `@State`, written in `onChange` with `withAnimation` | animated, same frames as the opt-in | same | same | | |
| `.transaction { $0.animation = nil }` under the opt-in | one step | one step | one step | | |
| `.animation(nil, value:)` under the opt-in | one step | one step | one step | | |
| Inserted view, transition with its own `.animation` | animated, 0.5 s | animated | animated (removal) | | |
| Inserted view, plain transition | one step | one step | one step | | |
| `GeometryReader` width | | one step each: 382 → 466 → 951 → 867 | one step: 867 → 382 | | one step: 382 → 594 |

- During the rotation, `body` logged `uikitInherited=0.3`: SwiftUI's update ran inside UIKit's rotation animation, and no SwiftUI value interpolated.
- The size-class change reached SwiftUI on open in the same update as the new size (`onChange` and the 951 pt width at 10.792 in run 2). On close, the size class came first, in its own update: about 25 ms (run 2, twice) and 70 ms (run 3) before the width changed.
- The width steps took 54 ms in run 2 (10.760 to 10.814) and 250 ms in run 3 (39.628 to 39.878).
- The width passes through 466 pt on open because the safe area insets (84 pt across the width, closed and open) drop before the resize and come back after it.

Time from the change to the first in-between value of the opt-in:

| Change | Delay |
|---|---|
| Size-class flip from code (8 flips) | 23 to 41 ms |
| Open or close (4) | 62 to 78 ms |
| Partially Open, and back to Open (2) | 38 to 58 ms |
| Rotation (2) | 138 ms once, 2.8 s once |

The first in-between value was always about 1/30 of the way, so the animation had started one 60 Hz frame earlier. We don't know why the first rotation took 2.8 s.

## Partial fold timing

In run 2, Partially Open started moving the hinge at 19.448 (172°). `onGeometryChange` reported the division region active at 20.466, right after the hinge settled at 127°. Back to Open, it reported inactive at 27.252, the same moment the hinge reached 180°. The region may change earlier and only be read at the next layout pass; we didn't separate the two.

## Hinge stream

While the simulator opened, `onHingeChange` updates arrived 30 to 180 ms apart, for example 160°, 167°, 169°, 172°, 174°, then `fullyOpen` at 180°. A device may report at another rate.

## Results we can't explain

- In run 2, the second Rotate Right press on the closed, sideways phone was followed by the phone opening. Run 3 repeated the same presses and the phone stayed closed. Another session may have pressed Open; we can't tell.
- TProbe's `GeometryReader` probe (an 8 pt square in a 10 pt-high reader) never logged. TProbe2's two variants (full-size `Color` and `Text`) logged as expected.
- A `transaction(_:)` closure on a `Text` that showed the size class and width did not run in every update. It skipped the update at 10.792 in run 2 where both changed, and every rotation. Logging from `transaction(_:)` is not a reliable probe; `Animatable` probes are.

## Raw output

Run 2, press Open (probe samples removed):

```text
TPROBE  10.624 hinge partiallyOpen 43
TPROBE  10.760 geometry width 382 -> 466
TPROBE  10.787 uikit willTransition(traits) h -> 1 animated=false duration=0.0
TPROBE  10.787 uikit willTransition(traits) h -> 2 animated=false duration=0.0
TPROBE  10.787 uikit viewWillTransition 466x678 -> 951x669 animated=false duration=0.0 curve=0
TPROBE  10.789 uikit trait h 1 -> 2 inherited=0.0
TPROBE  10.790 uikit layoutSubviews 466x678 -> 951x669 inherited=0.0
TPROBE  10.792 geometry width 466 -> 951
TPROBE  10.792 onChange hClass -> Optional(SwiftUI.UserInterfaceSizeClass.regular)
TPROBE  10.794 uikit alongside inherited=0.0 bounds=951x669
TPROBE  10.794 uikit completion cancelled=false bounds=951x669
TPROBE  10.814 geometry width 951 -> 867
```

Run 2, the probes in that update: the plain one jumps, the opt-in starts 65 ms later.

```text
TPROBE  10.792 sample hclass.plain 1.000
TPROBE  10.857 sample hclass.mirrored 0.033
TPROBE  10.857 sample hclass.optin 0.033
TPROBE  10.874 sample hclass.mirrored 0.067
TPROBE  10.874 sample hclass.optin 0.067
...
TPROBE  11.341 sample hclass.mirrored 1.000
TPROBE  11.341 sample hclass.optin 1.000
```

Run 3, first rotation (closed, portrait to landscape right):

```text
TPROBE2   4.811 uikit viewWillTransition 466x678 -> 678x466 animated=true duration=0.3
TPROBE2   4.828 body h=compact v=compact uikitInherited=0.3
TPROBE2   4.829 sample geo.b.width 594.000
TPROBE2   4.829 sample geo.a.width 594.000
TPROBE2   4.845 sample vclass.plain 1.000
```

## Build and run a probe

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer
mkdir -p TProbe2.app
xcrun -sdk iphonesimulator swiftc -target arm64-apple-ios27.1-simulator \
  -parse-as-library -o TProbe2.app/TProbe2 main.swift
# Add an Info.plist: CFBundleExecutable TProbe2, a bundle identifier, CFBundlePackageType APPL,
# MinimumOSVersion 27.1, UILaunchScreen, and portrait plus both landscape orientations.
codesign -s - --force TProbe2.app
xcrun simctl install booted TProbe2.app
xcrun simctl launch --console-pty --terminate-running-process booted <bundle-id> | grep TPROBE
```

Then press the pose and rotate buttons in Device Hub and read the lines. Uninstall the probe when you are done.

## Probe sources

The exact files we ran. They build in Swift 5 mode, as shown above.

### TProbe (runs 1 and 2)

```swift
// TProbe: what a fold, unfold, partial fold and rotation hand to SwiftUI and UIKit.
// Logs, per change:
//   UIKit: viewWillTransition(to:with:) and willTransition(to:with:) with the coordinator's
//          isAnimated / transitionDuration / completionCurve, the inherited UIView animation
//          duration inside the alongside block, in the trait handler and in layoutSubviews.
//   SwiftUI: the transaction's animation at a leaf, and whether Animatable probes get
//          in-between values (= the change animated) with no modifier, with
//          .animation(_:value:), and with a value mirrored through onChange + withAnimation.
import QuartzCore
import SwiftUI
import UIKit

let t0 = CACurrentMediaTime()
@MainActor func log(_ s: String) {
    print("TPROBE " + String(format: "%7.3f", CACurrentMediaTime() - t0) + " " + s)
    fflush(stdout)
}

// MARK: - SwiftUI probes

/// Logs every value SwiftUI hands it. Values strictly between the old and new target
/// mean SwiftUI interpolated the change, i.e. it animated.
struct Probe: ViewModifier, Animatable {
    let name: String
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        log("sample \(name) \(String(format: "%.3f", progress))")
        return content.opacity(0.99)
    }
}

struct TxnLogger: ViewModifier {
    let name: String
    func body(content: Content) -> some View {
        content.transaction { t in
            let a = t.animation.map { "\($0)" } ?? "nil"
            log("txn \(name) animation=\(a.prefix(80)) disables=\(t.disablesAnimations) continuous=\(t.isContinuous)")
        }
    }
}

/// Logs the phase SwiftUI animates an inserted or removed view through.
struct ProbeTransition: Transition {
    let name: String
    func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(Probe(name: name, progress: phase.isIdentity ? 1 : 0))
    }
}

/// Scripted phase: flips the size class from code with a plain state change (no
/// withAnimation), like a resize that carries no animation. Then hands back to the real trait.
struct ScriptedRoot: View {
    @State private var override: UserInterfaceSizeClass? = .compact
    var body: some View {
        ProbeView()
            .transformEnvironment(\.horizontalSizeClass) { value in
                if let override { value = override }
            }
            .task {
            for (delay, value) in [(2.0, UserInterfaceSizeClass.regular), (2.0, .compact), (2.0, .regular)] {
                try? await Task.sleep(for: .seconds(delay))
                log("---- scripted flip -> \(value)")
                override = value
            }
            try? await Task.sleep(for: .seconds(2))
            log("---- scripted phase over, real traits from now on")
            override = nil
        }
    }
}

struct ProbeView: View {
    @Environment(\.horizontalSizeClass) private var hClass
    @State private var width: CGFloat = 0
    @State private var foldActive = false
    @State private var mirroredWide = false

    var body: some View {
        let wide = hClass == .regular
        VStack(spacing: 4) {
            Text("h=\(wide ? "regular" : "compact") w=\(Int(width)) fold=\(foldActive ? "active" : "none")")
                .font(.caption.monospaced())
                .modifier(TxnLogger(name: "label"))
            Color.red.frame(width: 8, height: 8)
                .modifier(Probe(name: "hclass.plain", progress: wide ? 1 : 0))
            Color.green.frame(width: 8, height: 8)
                .modifier(Probe(name: "hclass.optin", progress: wide ? 1 : 0))
                .animation(.linear(duration: 0.5), value: hClass)
            Color.orange.frame(width: 8, height: 8)
                .modifier(Probe(name: "hclass.mirrored", progress: mirroredWide ? 1 : 0))
            Color.blue.frame(width: 8, height: 8)
                .modifier(Probe(name: "fold.plain", progress: foldActive ? 1 : 0))
            Color.yellow.frame(width: 8, height: 8)
                .modifier(Probe(name: "fold.optin", progress: foldActive ? 1 : 0))
                .animation(.linear(duration: 0.5), value: foldActive)
            Color.purple.frame(width: 8, height: 8)
                .modifier(Probe(name: "width.state", progress: width))
            // Read in the same update as the layout: interpolates only if the resize
            // itself reaches SwiftUI with an animation.
            GeometryReader { proxy in
                Color.pink.frame(width: 8, height: 8)
                    .modifier(Probe(name: "geo.width", progress: proxy.size.width))
            }
            .frame(height: 10)
            // Opt-out under an opt-in parent: should never interpolate.
            VStack {
                Color.gray.frame(width: 8, height: 8)
                    .modifier(Probe(name: "hclass.optout", progress: wide ? 1 : 0))
                    .transaction { $0.animation = nil }
            }
            .animation(.linear(duration: 0.5), value: hClass)
            VStack {
                Color.brown.frame(width: 8, height: 8)
                    .modifier(Probe(name: "hclass.optout.valuenil", progress: wide ? 1 : 0))
                    .animation(nil, value: hClass)
            }
            .animation(.linear(duration: 0.5), value: hClass)
            // A pane that exists only when wide: does its transition animate with no
            // animation in the transaction, if the transition carries its own?
            if wide {
                Color.cyan.frame(width: 8, height: 8)
                    .transition(ProbeTransition(name: "pane.ownanimation").animation(.linear(duration: 0.5)))
            }
            if wide {
                Color.mint.frame(width: 8, height: 8)
                    .transition(ProbeTransition(name: "pane.plain"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { new in
            log("geometry width \(Int(width)) -> \(Int(new)) uikitInherited=\(UIView.inheritedAnimationDuration)")
            width = new
        }
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.reservedRegions(kind: .division).contains { $0.isActive }
        } action: { new in
            log("geometry foldActive \(foldActive) -> \(new)")
            foldActive = new
        }
        .onChange(of: hClass, initial: true) { _, new in
            log("onChange hClass -> \(String(describing: new))")
            withAnimation(.linear(duration: 0.5)) { mirroredWide = new == .regular }
        }
        .onHingeChange { _, new in
            if let h = new.hinge { log("hinge \(h.status) \(Int(h.angle.degrees))") }
        }
    }
}

// MARK: - UIKit host

final class LoggingView: UIView {
    private var lastSize = CGSize.zero
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != lastSize else { return }
        log("uikit layoutSubviews \(Int(lastSize.width))x\(Int(lastSize.height)) -> \(Int(bounds.width))x\(Int(bounds.height)) inherited=\(UIView.inheritedAnimationDuration)")
        lastSize = bounds.size
    }
}

final class RootViewController: UIViewController {
    override func loadView() { view = LoggingView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let host = UIHostingController(rootView: ScriptedRoot())
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (self: Self, previous: UITraitCollection) in
            log("uikit trait h \(previous.horizontalSizeClass.rawValue) -> \(self.traitCollection.horizontalSizeClass.rawValue) inherited=\(UIView.inheritedAnimationDuration)")
        }
        log("start size \(Int(view.bounds.width))x\(Int(view.bounds.height)) maxFPS=\(view.window?.windowScene?.screen.maximumFramesPerSecond ?? -1)")
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        log("uikit viewWillTransition \(Int(view.bounds.width))x\(Int(view.bounds.height)) -> \(Int(size.width))x\(Int(size.height)) animated=\(coordinator.isAnimated) duration=\(coordinator.transitionDuration) curve=\(coordinator.completionCurve.rawValue)")
        super.viewWillTransition(to: size, with: coordinator)
        let queued = coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            log("uikit alongside inherited=\(UIView.inheritedAnimationDuration) bounds=\(Int(self.view.bounds.width))x\(Int(self.view.bounds.height))")
        }, completion: { [weak self] context in
            guard let self else { return }
            log("uikit completion cancelled=\(context.isCancelled) bounds=\(Int(self.view.bounds.width))x\(Int(self.view.bounds.height))")
        })
        log("uikit alongside queued=\(queued)")
    }

    override func willTransition(to newCollection: UITraitCollection, with coordinator: any UIViewControllerTransitionCoordinator) {
        log("uikit willTransition(traits) h -> \(newCollection.horizontalSizeClass.rawValue) animated=\(coordinator.isAnimated) duration=\(coordinator.transitionDuration)")
        super.willTransition(to: newCollection, with: coordinator)
    }
}

// MARK: - App

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = RootViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
```

### TProbe2 (run 3)

```swift
// TProbe2: follow-up to TProbe. Answers three questions on the shared iPhone Duo simulator:
//   1. Does a rotation reach SwiftUI with an animation in its transaction? (TProbe showed the
//      UIKit coordinator is animated for rotation, 0.3 s, and not animated for fold or unfold.)
//   2. Does a fold or unfold pass the scene through .inactive or rebuild the root view?
//   3. Does a GeometryReader-fed Animatable value interpolate on a resize? (TProbe's geo probe
//      never logged; two variants here.)
// An Animatable probe that logs values strictly between old and new targets = SwiftUI animated.
import QuartzCore
import SwiftUI
import UIKit

let t0 = CACurrentMediaTime()
@MainActor func log(_ s: String) {
    print("TPROBE2 " + String(format: "%7.3f", CACurrentMediaTime() - t0) + " " + s)
    fflush(stdout)
}

struct Probe: ViewModifier, Animatable {
    let name: String
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        log("sample \(name) \(String(format: "%.3f", progress))")
        return content.opacity(0.99)
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var phase
    @State private var token = String(UUID().uuidString.prefix(4))

    var body: some View {
        ProbeView()
            .onAppear { log("root appear token=\(token)") }
            .onDisappear { log("root disappear token=\(token)") }
            .onChange(of: phase, initial: true) { old, new in
                log("scenePhase \(old) -> \(new)")
            }
    }
}

struct ProbeView: View {
    @Environment(\.horizontalSizeClass) private var hClass
    @Environment(\.verticalSizeClass) private var vClass

    var body: some View {
        let hWide = hClass == .regular
        let vCompact = vClass == .compact
        let _ = log("body h=\(hWide ? "regular" : "compact") v=\(vCompact ? "compact" : "regular") uikitInherited=\(UIView.inheritedAnimationDuration)")
        VStack(spacing: 4) {
            Color.red.frame(width: 8, height: 8)
                .modifier(Probe(name: "vclass.plain", progress: vCompact ? 1 : 0))
            Color.green.frame(width: 8, height: 8)
                .modifier(Probe(name: "vclass.optin", progress: vCompact ? 1 : 0))
                .animation(.linear(duration: 0.5), value: vClass)
            Color.orange.frame(width: 8, height: 8)
                .modifier(Probe(name: "hclass.plain", progress: hWide ? 1 : 0))
            // Variant a: Color inside GeometryReader, full size.
            GeometryReader { proxy in
                Color.pink
                    .modifier(Probe(name: "geo.a.width", progress: proxy.size.width))
            }
            // Variant b: Text inside GeometryReader.
            GeometryReader { proxy in
                Text("\(Int(proxy.size.width))x\(Int(proxy.size.height))")
                    .font(.caption2.monospaced())
                    .modifier(Probe(name: "geo.b.width", progress: proxy.size.width))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onHingeChange { old, new in
            if old.hinge?.status != new.hinge?.status, let h = new.hinge {
                log("hinge \(h.status) \(Int(h.angle.degrees))")
            }
        }
    }
}

final class RootViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let host = UIHostingController(rootView: RootView())
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        log("uikit viewWillTransition \(Int(view.bounds.width))x\(Int(view.bounds.height)) -> \(Int(size.width))x\(Int(size.height)) animated=\(coordinator.isAnimated) duration=\(coordinator.transitionDuration)")
        super.viewWillTransition(to: size, with: coordinator)
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        log("scene willConnect")
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = RootViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
    func sceneDidDisconnect(_ scene: UIScene) { log("scene didDisconnect") }
    func sceneWillResignActive(_ scene: UIScene) { log("scene willResignActive") }
    func sceneDidBecomeActive(_ scene: UIScene) { log("scene didBecomeActive") }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
```
