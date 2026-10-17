# UIKit

The same shared screen in UIKit. `Seat` and `Facing` come from [SKILL.md](../SKILL.md#1-seats-seating-and-the-gate); they are plain Swift and work unchanged.

This code typechecks against the iOS 27.1 simulator SDK. We did not run it on the simulator. (unverified at run time)

## Two halves, each turned to its owner

```swift
import UIKit

/// The UIKit SharedSplit: two half views, side by side when wide, stacked when
/// tall, each turned to face its owner. Add your content to `first` and `second`.
final class SharedSplitView: UIView {
    let first = UIView()
    let second = UIView()
    var facing: Facing = .sameWay { didSet { setNeedsLayout() } }
    var spacing: CGFloat = 2 { didSet { setNeedsLayout() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        for half in [first, second] {
            half.clipsToBounds = true
            addSubview(half)
        }
        first.accessibilityIdentifier = Seat.first.id
        second.accessibilityIdentifier = Seat.second.id
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let sideBySide = bounds.width >= bounds.height
        let size = sideBySide
            ? CGSize(width: max(0, (bounds.width - spacing) / 2), height: bounds.height)
            : CGSize(width: bounds.width, height: max(0, (bounds.height - spacing) / 2))
        let secondOrigin = sideBySide
            ? CGPoint(x: size.width + spacing, y: 0)
            : CGPoint(x: 0, y: size.height + spacing)
        place(first, .first, in: CGRect(origin: .zero, size: size), sideBySide: sideBySide)
        place(second, .second, in: CGRect(origin: secondOrigin, size: size), sideBySide: sideBySide)
    }

    private func place(_ half: UIView, _ seat: Seat, in slot: CGRect, sideBySide: Bool) {
        let turns = facing.quarterTurns(for: seat, sideBySide: sideBySide)
        let sideways = turns % 2 != 0
        half.transform = .identity
        half.bounds = CGRect(x: 0, y: 0,
                             width: sideways ? slot.height : slot.width,
                             height: sideways ? slot.width : slot.height)
        half.center = CGPoint(x: slot.midX, y: slot.midY)
        half.transform = CGAffineTransform(rotationAngle: CGFloat(turns) * .pi / 2)
    }
}
```

- Set `bounds` and `center`, never `frame`, on a view with a transform ([UIView.transform](https://developer.apple.com/documentation/uikit/uiview/transform)).
- With UIKit's y axis pointing down, a positive angle turns the view clockwise on screen, matching `quarterTurns`. (From the transform's maths: "up", (0, -1), turned by +π/2 becomes "right", (1, 0). Not run in an app.)
- `hitTest(_:with:)` never reports points outside a view's bounds, even where a subview sticks out ([doc](https://developer.apple.com/documentation/uikit/uiview/hittest(_:with:))). So one half's overflow can't take the other person's taps. `clipsToBounds` also hides it.
- Touch locations: read `location(in:)` with the half (or a view inside it) as the reference, and you get the owner's coordinates.
- Place the halves left to right in every language, as the SwiftUI version does; content inside each half still follows `semanticContentAttribute` and the trait collection.

## Haptics, home indicator, edge gestures, idle timer

```swift
import UIKit

final class SharedPlayViewController: UIViewController {
    private let split = SharedSplitView()
    private lazy var firstHaptics = UIImpactFeedbackGenerator(style: .light, view: split.first)
    private lazy var secondHaptics = UIImpactFeedbackGenerator(style: .light, view: split.second)
    var isPlaying = false {
        didSet {
            setNeedsUpdateOfHomeIndicatorAutoHidden()
            setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
            UIApplication.shared.isIdleTimerDisabled = isPlaying
        }
    }

    override func loadView() {
        view = split
    }

    override var prefersHomeIndicatorAutoHidden: Bool { isPlaying }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { isPlaying ? .all : [] }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isPlaying = false
    }

    /// Plays a light tap for one seat. Both people feel it.
    func playPlaced(for seat: Seat, at location: CGPoint) {
        let generator = seat == .first ? firstHaptics : secondHaptics
        generator.impactOccurred(at: location)
    }
}
```

- `UIImpactFeedbackGenerator(style:view:)` (iOS 17.5) attaches the generator to the half as an interaction; `impactOccurred(at:)` takes a location in that view ([doc](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator/impactoccurred(at:))). The phone still vibrates as a whole. (unverified for iPhone Duo)
- `prefersHomeIndicatorAutoHidden` and `preferredScreenEdgesDeferringSystemGestures` are read-only overrides; call the matching `setNeedsUpdateOf…` method when the answer changes ([doc](https://developer.apple.com/documentation/uikit/uiviewcontroller/preferredscreenedgesdeferringsystemgestures)).
- Inside a container view controller, the container answers unless it points to your controller through `childForHomeIndicatorAutoHidden` and `childForScreenEdgesDeferringSystemGestures` ([doc](https://developer.apple.com/documentation/uikit/uiviewcontroller/childforhomeindicatorautohidden)).
- Reset `isIdleTimerDisabled` when play ends ([doc](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled)).
