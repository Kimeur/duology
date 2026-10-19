# UIKit transition patterns

Every block typechecks against the iOS 27.1 simulator SDK in Swift 5 mode, Swift 6 mode, and Swift 6 with `MainActor` as the default isolation. The coordinator facts in the first section are *measured* on the iPhone Duo simulator ([evidence.md](evidence.md)). The recipes are typechecked only: watch them in Device Hub before you rely on how they look.

## What the coordinator hands you

*Measured* with a probe view controller that logged [`viewWillTransition(to:with:)`](https://developer.apple.com/documentation/uikit/uicontentcontainer/viewwilltransition(to:with:)) and its coordinator on every change:

| Change | Size handed to you | `isAnimated` | `transitionDuration` | Alongside block |
|---|---|---|---|---|
| Open | 466 × 678 → 951 × 669 pt | `false` | 0 | Runs at once, `UIView.inheritedAnimationDuration` 0 |
| Close | 951 × 669 → 466 × 678 pt | `false` | 0 | Runs at once, inherited duration 0 |
| Rotate a quarter turn (closed or open) | Width and height swap | `true` | 0.3 s | Inherited duration 0.3 s; completion about 0.33 to 0.37 s later |
| Rotate a half turn | Same size | `true` | 0.6 s | Inherited duration 0.6 s |
| Partially open or open from partly open | No call | | | |

What follows from it:

- On rotation, layout you change inside the alongside block rides the system's animation. That is the classic UIKit pattern, and it still works.
- On open and close, the same block runs with no animation. Your layout takes its new place at once, together with the resize. That is one of the two valid choices; see "Should open and close animate?" in [SKILL.md](../SKILL.md).
- The trait change and the size transition don't arrive in a fixed order. In both closes we logged with a `registerForTraitChanges(_:handler:)` handler for the horizontal size class, it ran about 25 ms before `viewWillTransition(to:with:)`. In the two opens, it ran 2 ms after once and 19 ms before once. Decide layout from the size you are handed, or from the trait collection when the trait handler runs. Never assume one comes first.
- A partial fold sends no size transition. Only the fold's reserved region changes.

## Join the system's animation

```swift
import UIKit

final class NowPlayingViewController: UIViewController {
    private let artwork = UIImageView(image: UIImage(systemName: "music.note"))
    private let controls = UIStackView()
    private var tallConstraints: [NSLayoutConstraint] = []
    private var wideConstraints: [NSLayoutConstraint] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground       // one background for every size: no flash
        for subview in [artwork, controls] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        artwork.contentMode = .scaleAspectFit
        let guide = view.safeAreaLayoutGuide
        let margins = view.layoutMarginsGuide
        tallConstraints = [                            // artwork above, controls below
            artwork.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            artwork.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            artwork.widthAnchor.constraint(equalTo: margins.widthAnchor, multiplier: 0.8),
            artwork.heightAnchor.constraint(equalTo: artwork.widthAnchor),
            controls.topAnchor.constraint(equalTo: artwork.bottomAnchor, constant: 24),
            controls.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
        ]
        wideConstraints = [                            // artwork leading, controls trailing
            artwork.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            artwork.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
            artwork.heightAnchor.constraint(equalTo: guide.heightAnchor, multiplier: 0.7),
            artwork.widthAnchor.constraint(equalTo: artwork.heightAnchor),
            controls.leadingAnchor.constraint(equalTo: artwork.trailingAnchor, constant: 32),
            controls.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
        ]
        applyLayout(isWide: view.bounds.width > view.bounds.height)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let isWide = size.width > size.height          // decide from the size you are handed
        coordinator.animate(alongsideTransition: { _ in
            // Rotation: rides the system's 0.3 s animation. Open and close: applies at once.
            self.applyLayout(isWide: isWide)
            self.view.layoutIfNeeded()
        })
    }

    private func applyLayout(isWide: Bool) {
        NSLayoutConstraint.deactivate(isWide ? tallConstraints : wideConstraints)
        NSLayoutConstraint.activate(isWide ? wideConstraints : tallConstraints)
    }
}
```

- The same views and constraints stay in place; only which constraints are active changes. Nothing is rebuilt, so nothing flashes.
- [`animate(alongsideTransition:completion:)`](https://developer.apple.com/documentation/uikit/uiviewcontrollertransitioncoordinator/animate(alongsidetransition:completion:)) runs your block in the transition's own animation context, with its timing. It returns `false` when it can't queue the block; the completion can still run.
- Keep work that must not animate, such as prefetching for the new column count, in the completion block.

## Optional motion on open and close

Only if you decided, on a device, that open and close need motion. The coordinator brings none, so you supply it. *Typechecked only; we did not watch it on screen.*

```swift
import SwiftUI   // UIView.animate(_:changes:completion:) is declared in SwiftUI
import UIKit

final class ShelfViewController: UIViewController {
    private var tallConstraints: [NSLayoutConstraint] = []
    private var wideConstraints: [NSLayoutConstraint] = []

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let isWide = size.width > size.height
        let apply = {
            self.applyLayout(isWide: isWide)
            self.view.layoutIfNeeded()
        }
        coordinator.animate(alongsideTransition: { context in
            if context.isAnimated { apply() }          // rotation: the system's animation
        }, completion: { context in
            guard !context.isAnimated else { return }
            // Open and close arrive with no animation: a short spring of your own, or none.
            if UIAccessibility.isReduceMotionEnabled {
                apply()
            } else {
                UIView.animate(.smooth(duration: 0.3), changes: apply)
            }
        })
    }

    private func applyLayout(isWide: Bool) {
        NSLayoutConstraint.deactivate(isWide ? tallConstraints : wideConstraints)
        NSLayoutConstraint.activate(isWide ? wideConstraints : tallConstraints)
    }
}
```

- *Measured:* on open and close the completion ran 7 ms or less after `viewWillTransition(to:with:)`, so the motion still starts with the resize, not a beat later.
- [`UIView.animate(_:changes:completion:)`](https://developer.apple.com/documentation/uikit/uiview/animate(_:changes:completion:)) (iOS 18) takes a SwiftUI `Animation`, so UIKit and SwiftUI screens can share one spring.
- Start your own animation in the completion block, as above, not inside the alongside block. Apple's docs say a UIKit animation started inside another one takes the remaining duration of the one in flight unless you pass [`.overrideInheritedDuration`](https://developer.apple.com/documentation/uikit/uiview/animationoptions/overrideinheritedduration).

## Collection view columns that move with the resize

```swift
import UIKit

final class AlbumGridViewController: UICollectionViewController {
    init() {
        let layout = UICollectionViewCompositionalLayout { _, environment in
            // Columns from the container's own width, even counts (duo-patterns, feed reflow).
            let width = environment.container.effectiveContentSize.width
            let columns = max(2, Int(width / 180) / 2 * 2)
            let fraction = 1.0 / CGFloat(columns)
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(fraction), heightDimension: .fractionalWidth(fraction)))
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalWidth(fraction)),
                repeatingSubitem: item, count: columns)
            return NSCollectionLayoutSection(group: group)
        }
        super.init(collectionViewLayout: layout)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            // New column count, laid out inside the transition: cells glide on rotation
            // and take their new place at once on open and close.
            // Never reloadData() here: it rebuilds cells and loses selection.
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.layoutIfNeeded()
        })
    }
}
```

- Keep the top item in view after the change. `duo-continuity` measured that scrolling inside the trait handler doesn't stick, and scrolling after the next layout pass does ([duo-continuity, UIKit](https://github.com/Kimeur/duology/blob/main/plugins/duology/skills/duo-continuity/SKILL.md#9-uikit)).

## A partial fold has no coordinator

The fold's reserved region changes, the window doesn't. Read the region in the `layoutSubviews` of the view that lays out around the fold, and animate the move yourself. UIKit runs that pass again when the fold turns active or inactive, so you need no hinge observer. Make that view the controller's root view.

```swift
import SwiftUI   // for UIView.animate(_:changes:completion:)
import UIKit

@available(iOS 27.1, *)
final class RecorderViewController: UIViewController {
    override func loadView() { view = RecorderView() }
}

@available(iOS 27.1, *)
final class RecorderView: UIView {
    let recordGroup = UIStackView()
    private var lastFold: CGRect?
    private var lastSize = CGSize.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(recordGroup)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Reading the regions here is enough: UIKit lays this view out again
        // when the fold turns active or inactive. No hinge observer needed.
        // Work out the place on every pass: open, close, rotation and Split View move it too.
        let fold = reservedRegions(kind: .division, options: .includeInactive)
            .first(where: \.isActive)?.frame
        let size = bounds.size
        let target = targetFrame(avoiding: fold)
        // Only the fold changed, in a window that kept its size: a partial fold.
        let foldOnly = fold != lastFold && size == lastSize
        lastFold = fold
        lastSize = size
        guard recordGroup.frame != target else { return }
        if foldOnly && !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(.smooth) { self.recordGroup.frame = target }
        } else {
            // First pass, a resize or a safe-area change: take the new place at once.
            // During a rotation this pass runs inside the system's animation and glides with it.
            recordGroup.frame = target
        }
    }

    private func targetFrame(avoiding fold: CGRect?) -> CGRect {
        let size = recordGroup.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let area = bounds.inset(by: safeAreaInsets)
        // Folded like a book: the trailing region. Otherwise: bottom centre.
        let region: CGRect
        if let fold, fold.height > fold.width {
            region = CGRect(x: fold.maxX, y: area.minY, width: area.maxX - fold.maxX, height: area.height)
        } else if let fold {
            region = CGRect(x: area.minX, y: fold.maxY, width: area.width, height: area.maxY - fold.maxY)
        } else {
            region = area
        }
        return CGRect(x: region.midX - size.width / 2, y: region.maxY - size.height - 16,
                      width: size.width, height: size.height)
    }
}
```

- [`reservedRegions(kind:options:)`](https://developer.apple.com/documentation/uikit/uiview/reservedregions(kind:options:)) is iOS 27.1. *Measured in SwiftUI:* the fold read as active about 1 s after the hinge started to fold, once it stopped at 127°. *Measured in UIKit* ([duo-postures measurements](https://github.com/Kimeur/duology/blob/main/plugins/duology-design/skills/duo-postures/references/measurements.md#uikit-layout-passes-on-a-fold)): a view that reads the regions in its own `layoutSubviews` got a pass in the frame the region turned active, and another when it turned inactive. A view that never read them got no pass.
- Don't nudge this pass from a [`UIHingeInteraction`](https://developer.apple.com/documentation/uikit/uihingeinteraction). When folding, the hinge status turned `partiallyOpen` 0.7 to 0.9 s before the region turned active, so a pass on a status change reads the old, inactive region. A pass on every hinge update ran up to about 30 times a second while folding and added nothing. Keep the hinge for effects.
- The guard skips passes where the target didn't change, so other layout passes cost one cheap frame calculation.
- Animate only when the fold changed and the window kept its size. Open and close bring no system motion, so after a resize the group takes its new place at once, like the rest of the layout. *Measured* ([evidence.md](evidence.md)): during a rotation, `layoutSubviews` ran with `UIView.inheritedAnimationDuration` 0.3, so the direct set rides the rotation's animation.
- Don't compare only the fold. When the phone is closed there is no division, and when it is open and flat the division is inactive, so the fold reads `nil` before and after a resize. A guard on the fold alone leaves the group at its old place: below the bottom edge after a rotation, or near x = 233 pt in a 951 pt window after an open.
- Keep the move small and keep the control's edge: bottom stays bottom (`duo-patterns`, displacement).

## Reduce Motion and cross-fade

```swift
import SwiftUI   // for UIView.animate(_:changes:completion:)
import UIKit

enum MotionSettings {
    /// Reduce Motion is on: no movement. Positions change at once.
    @MainActor static var reducesMotion: Bool { UIAccessibility.isReduceMotionEnabled }
    /// Reduce Motion and Prefer Cross-Fade Transitions are both on: replace slides with fades.
    @MainActor static var prefersCrossFade: Bool { UIAccessibility.prefersCrossFadeTransitions }
}

final class SettingsAwareViewController: UIViewController {
    func showPane(_ pane: UIView, in container: UIView) {
        if MotionSettings.reducesMotion {
            // A short fade is not motion: keep it under Reduce Motion.
            UIView.transition(with: container, duration: 0.2, options: .transitionCrossDissolve) {
                container.addSubview(pane)
            }
        } else {
            pane.transform = CGAffineTransform(translationX: 40, y: 0)
            pane.alpha = 0
            container.addSubview(pane)
            UIView.animate(.smooth) {
                pane.transform = .identity
                pane.alpha = 1
            }
        }
    }
}
```

- Read the settings each time you animate; then there's nothing to redo when they change. Observe `UIAccessibility.reduceMotionStatusDidChangeNotification` only for motion that is already running, such as a looping effect.
- [`isReduceMotionEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isreducemotionenabled) dates from iOS 8, `prefersCrossFadeTransitions` from iOS 14.

## Red flags

- Layout changes in the coordinator's completion block when `context.isAnimated` is `true`: the rotation finishes, then the layout jumps.
- `reloadData()`, new child view controllers or new cells in `viewWillTransition(to:with:)` or a trait handler.
- Code that expects the trait change before the size transition, or after it.
- `DispatchQueue.main.asyncAfter` to "wait for the rotation to finish" before laying out.
- A background colour or a font size picked by size class.

## Sources

- Apple pages linked inline: `viewWillTransition(to:with:)`, `animate(alongsideTransition:completion:)`, `UIView.animate(_:changes:completion:)`, `UIView.AnimationOptions`, `UIHingeInteraction`, `reservedRegions(kind:options:)`, `isReduceMotionEnabled`.
- [Adapting your app when traits change](https://developer.apple.com/documentation/uikit/adapting-your-app-when-traits-change): `registerForTraitChanges(_:handler:)` instead of `traitCollectionDidChange(_:)`.
