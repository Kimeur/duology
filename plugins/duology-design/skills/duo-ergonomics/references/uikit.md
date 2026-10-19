# duo-ergonomics in UIKit

Depth for [`../SKILL.md`](../SKILL.md). The same rules as the SwiftUI sections, in UIKit. Every snippet typechecks against the iOS 27.1 simulator SDK.

The UIKit names, all iOS 27.1 ([API index](https://github.com/Kimeur/duology/blob/main/reference/api-index.md#navigation-and-bars-uikit)):

- `UITraitCollection.verticalBarEdge`: `.leading`, `.trailing` or `.unspecified`. Apple's doc says it gives the system's preferred edge whether or not a bar is showing, and `.unspecified` where the system never places a vertical bar ([doc](https://developer.apple.com/documentation/uikit/uitraitcollection/verticalbaredge)).
- `UITraitCollection.systemTraitsAffectingVerticalBarEdge`: pass it to `registerForTraitChanges(_:handler:)` to hear when the edge may change.
- `UIOverlayArrangement` with `ViewProperties.edge`: the edge the view takes when the overlay goes side by side (SDK header `UIOverlayArrangement.h`).

## Floating button near the thumb

The UIKit version of `ThumbCorner`. Leading and trailing anchors flip in right-to-left languages, the same way `verticalBarEdge` does, so the button follows the bar without extra code.

```swift
import UIKit

// requires: HandPreference (SKILL.md, section 2)

/// Pins one floating button to the bottom corner nearest the thumb.
@available(iOS 27.1, *)
final class ThumbButtonViewController: UIViewController {
    /// Your own setting for floating controls. System bars ignore it.
    var handPreference = HandPreference.automatic {
        didSet { placeButton() }
    }

    private let button = UIButton(type: .system)
    private var leadingPin: NSLayoutConstraint?
    private var trailingPin: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "location.fill")
        config.cornerStyle = .capsule
        config.buttonSize = .large
        button.configuration = config
        button.accessibilityLabel = "My Location"
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)

        let guide = view.safeAreaLayoutGuide
        // 16 pt from the edge: next to a vertical bar the margin is 0.
        leadingPin = button.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16)
        trailingPin = guide.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: 16)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 56),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            guide.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: 16),
        ])

        registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) {
            (self: Self, _: UITraitCollection) in
            self.placeButton()
        }
        placeButton()
    }

    private func placeButton() {
        guard isViewLoaded else { return }
        let leftToRight = view.effectiveUserInterfaceLayoutDirection == .leftToRight
        let onLeading = switch handPreference {
        case .left: leftToRight
        case .right: !leftToRight
        case .automatic: traitCollection.verticalBarEdge == .leading  // .unspecified: trailing
        }
        // Turn one pin off before the other goes on, so they never conflict.
        (onLeading ? trailingPin : leadingPin)?.isActive = false
        (onLeading ? leadingPin : trailingPin)?.isActive = true
    }
}
```

Not run on the simulator; the SwiftUI version was (see [measured.md](measured.md)). With right to left forced, SwiftUI's edge read `.leading` while the bar stayed on the right, and we expect `verticalBarEdge` to do the same. *Unverified* in UIKit.

## Controls in the bottom half or on the bar's half

An overlay arrangement puts its primary in the trailing or bottom part when the phone is partly open ([hub](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo#Arrange-views-in-different-poses)). Make the controls the primary. This version also sends them to the bar's half when the overlay goes side by side, so they stay with the bar in right-to-left languages (*judgement*, *unverified* folded).

```swift
import UIKit

/// Video behind, controls in front. Partly open, the controls move to the bottom (tabletop)
/// or to the half with the vertical bar (book).
@available(iOS 27.1, *)
final class PlayerContainerViewController: UIViewController {
    private let arrangement = UIArrangementViewController()
    private let controls: UIViewController
    private let video: UIViewController

    init(controls: UIViewController, video: UIViewController) {
        self.controls = controls
        self.video = video
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(arrangement)
        arrangement.view.frame = view.bounds
        arrangement.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arrangement.view)
        arrangement.didMove(toParent: self)

        arrangement.setViewController(controls, for: .primary)
        arrangement.setViewController(video, for: .secondary)
        applyOverlay()
        registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) {
            (self: Self, _: UITraitCollection) in
            self.applyOverlay()
        }
    }

    private func applyOverlay() {
        var overlay = UIOverlayArrangement()
        var controlsProperties = overlay.defaultViewProperties
        controlsProperties.edge = traitCollection.verticalBarEdge == .leading ? .leading : .trailing
        overlay.setViewProperties(controlsProperties, for: .primary)
        arrangement.updateArrangement(overlay, animated: true)
    }
}
```

Inside the controls view controller, pin the control strip to the bottom of its safe area. Flat, the primary covers the whole screen; `duo-patterns` measured a short SwiftUI primary at the top edge, out of thumb reach.

## Targets of 44 pt

```swift
import UIKit

/// An icon button whose hit region is never smaller than 44 x 44 pt.
@MainActor
func makeIconButton(title: String, systemImage: String, action: UIAction) -> UIButton {
    var config = UIButton.Configuration.plain()
    config.image = UIImage(systemName: systemImage)
    let button = UIButton(configuration: config, primaryAction: action)
    button.accessibilityLabel = title
    button.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
    ])
    return button
}
```

- The button's bounds take the taps, so the 44 pt constraints make the hit region 44 pt even when the symbol is small.
- For a frequent control on a phone that sits on a table, use `config.buttonSize = .large` as well (*judgement*).
- Keep 12 pt or more between bezeled buttons ([HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Mobility)).

## Keep the bar where it is

Don't return `.disabled` from `preferredVerticalBarBehavior` to move controls for one hand. Apple names three cases for turning vertical bars off: a calculator-like screen, a full-screen video player and a sheet with a single Close item ([talk 111462, 14:20](https://developer.apple.com/videos/play/tech-talks/111462/?time=860), [doc](https://developer.apple.com/documentation/swiftui/view/toolbarverticalbehavior(_:)); details in `duo-navigation`). One-handed use is not one of them.
