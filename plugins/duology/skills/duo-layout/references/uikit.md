# UIKit

The rules in [SKILL.md](../SKILL.md) apply to UIKit unchanged. This page gives the UIKit spelling for each.

Apple sources: [Adapting your app when traits change](https://developer.apple.com/documentation/uikit/adapting-your-app-when-traits-change), [Automatic trait tracking](https://developer.apple.com/documentation/uikit/automatic-trait-tracking), [UIView.reservedRegions(kind:options:)](https://developer.apple.com/documentation/uikit/uiview/reservedregions(kind:options:)), [UIArrangementViewController](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller), [UIHingeInteraction](https://developer.apple.com/documentation/uikit/uihingeinteraction), [Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/).

## Size classes

Read `traitCollection.horizontalSizeClass` and `verticalSizeClass`. Don't read `UIDevice.current.userInterfaceIdiom` or any orientation for layout ([overview](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)).

Read traits inside a method that supports automatic trait tracking, and UIKit calls it again when they change. For properties that invalidate layout, such as a stack view's axis, Apple points you to `updateProperties()` (iOS 26) rather than `layoutSubviews()`.

```swift
import UIKit

final class LibraryViewController: UIViewController {
    private let stack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let guide = view.layoutMarginsGuide
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    // UIKit records the traits read here and calls this again when they change.
    override func updateProperties() {
        super.updateProperties()
        stack.axis = traitCollection.horizontalSizeClass == .regular ? .horizontal : .vertical
    }
}
```

Deploying below iOS 26, register instead:

```swift
import UIKit

final class LegacyLibraryViewController: UIViewController {
    private let stack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        updateAxis()
        registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (self: Self, _: UITraitCollection) in
            self.updateAxis()
        }
    }

    private func updateAxis() {
        stack.axis = traitCollection.horizontalSizeClass == .regular ? .horizontal : .vertical
    }
}
```

## Screen and scale

`UIScreen.main` is deprecated since iOS 26 and is ambiguous on a phone with two displays.

```swift
import UIKit

extension UIView {
    /// The scale of the display this view is on. Replaces UIScreen.main.scale.
    var displayScaleForDrawing: CGFloat { traitCollection.displayScale }

    /// The screen this view is on, when you truly need it. Replaces UIScreen.main.
    var currentScreen: UIScreen? { window?.windowScene?.screen }
}
```

Lay out from `view.bounds`, never from a screen's bounds.

## Safe areas and margins

Each side has its own inset. Don't compute one and double it.

```swift
import UIKit

final class PosterView: UIView {
    let artwork = UIImageView()
    let caption = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(artwork)
        addSubview(caption)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Background: the full bounds, under the bars.
        artwork.frame = bounds
        // Foreground: inside the real insets, side by side.
        let content = bounds.inset(by: safeAreaInsets)
        let height = caption.sizeThatFits(content.size).height
        caption.frame = CGRect(x: content.minX, y: content.maxY - height, width: content.width, height: height)
    }
}
```

With Auto Layout, pin controls to `safeAreaLayoutGuide` or `layoutMarginsGuide`. Margins are asymmetric too: foreground content may sit closer to a vertical bar than to the opposite edge ([111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=366)).

## Reserved regions

`view.reservedRegions(kind:options:)` returns `[UIView.ReservedRegion]` in the view's coordinates. Unlike SwiftUI, UIKit does not mirror the frames for right-to-left, so pick the trailing side yourself.

*Measured:* UIKit returned the same frames as SwiftUI in our probe: no regions by default when flat, the inactive fold with `.includeInactive`. See [reserved-regions.md](reserved-regions.md#what-we-measured).

```swift
import UIKit

final class PlayerViewController: UIViewController {
    private let controls = UIStackView()
    private var lastStatus: UIHinge.Status?

    // A fold doesn't change the view's size. This makes sure layout runs again
    // when the hinge status changes. Layout still comes from the regions.
    private lazy var hingeWatcher = UIHingeInteraction { [weak self] _, update in
        guard let self, let status = update.hinge?.status, status != self.lastStatus else { return }
        self.lastStatus = status
        self.view.setNeedsLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(controls)
        view.addInteraction(hingeWatcher)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let area = controlArea()
        let size = controls.systemLayoutSizeFitting(area.size)
        controls.frame = CGRect(
            x: area.midX - size.width / 2,
            y: area.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// The safe area when flat; the trailing or bottom side of the fold when folded.
    private func controlArea() -> CGRect {
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        let folds = view.reservedRegions(kind: .division).filter(\.isActive)
        guard let fold = folds.first?.frame, fold.intersects(safe) else { return safe }
        if fold.height >= fold.width {
            let rightToLeft = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
            return rightToLeft
                ? CGRect(x: safe.minX, y: safe.minY, width: fold.minX - safe.minX, height: safe.height)
                : CGRect(x: fold.maxX, y: safe.minY, width: safe.maxX - fold.maxX, height: safe.height)
        }
        return CGRect(x: safe.minX, y: fold.maxY, width: safe.width, height: safe.maxY - fold.maxY)
    }
}
```

Whether UIKit lays out again on its own when only the fold changes is unverified. The hinge interaction above is a cheap safety net. UIKit's hinge reports `UIHinge.Status` (`.unknown`, `.closed`, `.partiallyOpen`, `.fullyOpen`) and `angle` in radians. Don't lay out from the angle.

## Arrangements

`UIArrangementViewController` is the UIKit `ArrangementView`. Put it inside your navigation controller, not the other way round ([111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=677)).

```swift
import UIKit

@MainActor
func makeNowPlaying() -> UINavigationController {
    let arrangement = UIArrangementViewController()
    arrangement.setViewController(NowPlayingViewController(), for: .primary)
    arrangement.setViewController(QueueViewController(), for: .secondary)

    // Split side by side only. Ask for 60 percent for the primary.
    var split = UISplitArrangement().axes(.horizontal)
    var primary = split.defaultViewProperties
    primary.width.preferred = .fractional(0.6)
    split.setViewProperties(primary, for: .primary)
    arrangement.updateArrangement(split)

    return UINavigationController(rootViewController: arrangement)
}
```

`UISplitArrangement` and `UIOverlayArrangement` are value types: change a copy, then pass it to `updateArrangement(_:animated:)`. For the simple cases, `arrangement.updateArrangement(.split.axes(.horizontal))` and `arrangement.updateArrangement(.overlay)` work as written. `.fractional(0.6)` reads as a share of the container; Apple's page doesn't spell that out (unverified).

Overlay, with the primary moving to the trailing side when the overlay turns side by side:

```swift
import UIKit

@MainActor
func useOverlay(on arrangement: UIArrangementViewController) {
    var overlay = UIOverlayArrangement()
    var controls = overlay.defaultViewProperties
    controls.edge = .trailing
    overlay.setViewProperties(controls, for: .primary)
    arrangement.updateArrangement(overlay, animated: true)
}
```

A child reads its placement through `arrangementViewController` and `state(for:)`. `ViewState` gives `zIndex`, `splitAxis` and `isHidden`.

*Measured* (iOS 27.1 simulator, an arrangement in a 678 × 466 pt frame with `traitOverrides` for the size classes):

- Compact width and compact height: only the primary's view entered the window. The secondary's view never did, yet `state(for: .secondary)?.isHidden` was `false`. To know whether the secondary shows, check `viewController(for: .secondary)?.viewIfLoaded?.window != nil`, or better, make the primary complete on its own.
- Regular / regular: side by side, 339 pt each. Each child's `traitCollection` read compact width, the same as in SwiftUI.
- Overlay: both children full size; `zIndex` was 1 for the primary and 0 for the secondary, and it was already set inside the child's `viewDidLayoutSubviews()`.

```swift
import UIKit

final class QueueViewController: UIViewController {
    private var isCollapsed = false

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let arrangement = arrangementViewController,
              let placement = arrangement.placement(for: self),
              let state = arrangement.state(for: placement) else { return }
        let collapsed = state.zIndex > 0
        guard collapsed != isCollapsed else { return }
        isCollapsed = collapsed
        // Swap to the collapsed or expanded queue here.
    }
}
```

Which callback runs when only the fold changes is unverified. `viewDidLayoutSubviews()` runs whenever the child's frame changes, which covers the cases we measured.

## Even split

The UIKit `EvenSplit`: a `UIStackView` with `.fillEqually`, axis chosen from the view's own shape. The child views are the same objects before and after the flip, so their state survives.

```swift
import UIKit

final class EvenSplitViewController: UIViewController {
    private let stack = UIStackView()
    private let halves: [UIViewController]

    init(primary: UIViewController, secondary: UIViewController, spacing: CGFloat = 0) {
        halves = [primary, secondary]
        super.init(nibName: nil, bundle: nil)
        stack.distribution = .fillEqually
        stack.spacing = spacing
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        stack.frame = view.bounds
        stack.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(stack)
        for half in halves {
            addChild(half)
            half.view.clipsToBounds = true
            stack.addArrangedSubview(half.view)
            half.didMove(toParent: self)
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let axis: NSLayoutConstraint.Axis = view.bounds.width >= view.bounds.height ? .horizontal : .vertical
        if stack.axis != axis { stack.axis = axis }
    }
}
```

## Availability

Reserved regions, `UIArrangementViewController` and `UIHingeInteraction` need iOS 27.1. If you deploy lower, wrap them in `if #available(iOS 27.1, *)` and fall back to a plain `UIStackView` or `UISplitViewController`.
