# UIKit

The same rules as the SwiftUI recipes: size classes for the big decision, the `.division` reserved region for where the fold is, and the hinge only for effects ([hinge.md](hinge.md#uikit)).

| Need | UIKit | Availability |
|---|---|---|
| Compact or regular | `traitCollection.horizontalSizeClass`, with `registerForTraitChanges(_:handler:)` | iOS 17 |
| Where the fold is | [`reservedRegions(kind:options:)`](https://developer.apple.com/documentation/uikit/uiview/reservedregions(kind:options:)) on `UIView`, kind `.division`, option `.includeInactive` | iOS 27.1 |
| Is it folded | `isActive` on the returned `UIView.ReservedRegion` | iOS 27.1 |
| Two views that adapt on their own | [`UIArrangementViewController`](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller) with `.overlay` or `.split` | iOS 27.1 |

## A view that lays out by fold regions

`FoldRegionsView` does what `FoldRegionsLayout` does in its overlay style: the content fills the safe area with the controls at the bottom, until an active fold splits the two.

```swift
import UIKit

/// Content first, controls second, in the regions a fold makes.
/// No active fold: content fills the safe area and the controls sit at the bottom, over it.
@available(iOS 27.1, *)
final class FoldRegionsView: UIView {
    let contentView: UIView
    let controlsView: UIView
    private var lastHingeStatus: UIHinge.Status?

    init(content: UIView, controls: UIView) {
        contentView = content
        controlsView = controls
        super.init(frame: .zero)
        addSubview(content)
        addSubview(controls)
        // UIKit has no callback for region changes. Re-layout when the hinge
        // status changes; the regions, not the hinge, decide where views go.
        addInteraction(UIHingeInteraction { [weak self] _, update in
            guard let self, update.hinge?.status != lastHingeStatus else { return }
            lastHingeStatus = update.hinge?.status
            setNeedsLayout()
        })
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let area = bounds.inset(by: safeAreaInsets)
        guard let fold = reservedRegions(kind: .division, options: .includeInactive)
            .first(where: \.isActive)?.frame else {
            contentView.frame = bounds
            let size = controlsSize(width: area.width)
            controlsView.frame = CGRect(x: area.midX - size.width / 2, y: area.maxY - size.height,
                                        width: size.width, height: size.height)
            return
        }
        let first: CGRect
        let second: CGRect
        if fold.height > fold.width {
            // Book: the fold runs top to bottom. Content goes on the leading side.
            let left = CGRect(x: area.minX, y: area.minY, width: fold.minX - area.minX, height: area.height)
            let right = CGRect(x: fold.maxX, y: area.minY, width: area.maxX - fold.maxX, height: area.height)
            let isRightToLeft = effectiveUserInterfaceLayoutDirection == .rightToLeft
            (first, second) = isRightToLeft ? (right, left) : (left, right)
        } else {
            // Tabletop: the fold runs side to side. Content on top.
            first = CGRect(x: area.minX, y: area.minY, width: area.width, height: fold.minY - area.minY)
            second = CGRect(x: area.minX, y: fold.maxY, width: area.width, height: area.maxY - fold.maxY)
        }
        contentView.frame = first
        let size = controlsSize(width: second.width)
        controlsView.frame = CGRect(x: second.midX - size.width / 2, y: second.midY - size.height / 2,
                                    width: size.width, height: size.height)
    }

    /// The controls' own size, never wider than the space they get.
    private func controlsSize(width: CGFloat) -> CGSize {
        let size = controlsView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height))
        return CGSize(width: min(size.width, width), height: size.height)
    }
}
```

Notes:

- UIKit returns region frames in the view's own coordinates, with no mirroring for right-to-left that the headers mention. So the code picks the leading side itself. Not yet tested in a right-to-left language. (unverified)
- The hinge interaction only asks for a new layout pass. It never decides where a view goes, so the layout stays right when the phone is flipped or in Split View.
- We have not checked on the simulator whether a fold change calls `layoutSubviews` without that nudge. (unverified)
- Animate the change with `UIView.animate` around `layoutIfNeeded()` only when `UIAccessibility.isReduceMotionEnabled` is false.
- Unlike the SwiftUI recipe, this version doesn't check that the fold crosses the middle of the view. Add that check if the view can sit beside the fold, for example in one column of a split view.

## The system alternative

`UIArrangementViewController` with `.overlay` gives the same behaviour with no fold code: primary over secondary when nothing is folded, primary in the trailing or bottom part when partly open ([hub](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)).

```swift
import UIKit

@available(iOS 27.1, *)
@MainActor
func makeArrangedPlayer(video: UIViewController, controls: UIViewController) -> UIArrangementViewController {
    let arrangement = UIArrangementViewController()
    arrangement.setViewController(controls, for: .primary)
    arrangement.setViewController(video, for: .secondary)
    arrangement.updateArrangement(.overlay)
    return arrangement
}
```

Put it inside a `UINavigationController` or a tab, never the other way round. Not yet checked folded on the simulator. (unverified)
