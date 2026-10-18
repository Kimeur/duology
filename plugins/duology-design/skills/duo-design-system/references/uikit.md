# The design system in UIKit

The tokens are plain values, so UIKit uses the same `DuoTokens.swift`. Only the reading changes: from the trait collection instead of the SwiftUI environment. Every rule in [SKILL.md](../SKILL.md) applies unchanged.

| SwiftUI | UIKit |
|---|---|
| `@DuoMetrics private var tokens` | `DuoTokens(traitCollection)` (below), re-read on trait changes |
| `duoContainerMargins()` | `layoutMarginsGuide`, `directionalLayoutMargins`; per side, never one value doubled |
| `duoReadableWidth(_:)` | [`readableContentGuide`](https://developer.apple.com/documentation/uikit/uiview/readablecontentguide) |
| `DuoType` roles | `UIFont.preferredFont(forTextStyle:)` with `adjustsFontForContentSizeCategory = true` |
| `@ScaledMetric` | `UIFontMetrics(forTextStyle:).scaledValue(for:compatibleWith:)` |
| `ConcentricRectangle` | `cornerConfiguration = .corners(radius: .containerConcentric(minimum:))` (iOS 26) |
| `.glassEffect`, `.buttonStyle(.glass)` | `UIGlassEffect` in a `UIVisualEffectView`; `UIButton.Configuration.glass()` (iOS 26) |
| `DuoColor` | `UIColor.systemBackground` and friends; `UIColor(dynamicProvider:)` for custom colours |

Apple's Duo talk names `UICornerConfiguration` as the UIKit side of corner concentricity ([111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=269)), and asks you to handle each safe area inset and layout margin on its own ([111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=445)).

## Code

Typechecked against the iOS 27.1 simulator SDK in Swift 5, Swift 6 and main actor default isolation modes, together with `DuoTokens.swift`.

```swift
import UIKit

// requires: DuoTokens.swift

@MainActor
extension DuoTokens {
    /// Tokens from a trait collection: size class, text size, readable width.
    init(_ traits: UITraitCollection) {
        self.init(widthClass: traits.horizontalSizeClass == .regular ? .regular : .compact,
                  isAccessibilitySize: traits.preferredContentSizeCategory.isAccessibilityCategory,
                  readableWidth: UIFontMetrics(forTextStyle: .body)
                      .scaledValue(for: 600, compatibleWith: traits))
    }
}

@available(iOS 26.0, *)
final class CardCell: UICollectionViewCell {
    private let title = UILabel()
    private let thumbnail = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        title.font = .preferredFont(forTextStyle: .headline)
        title.adjustsFontForContentSizeCategory = true
        title.numberOfLines = 0
        thumbnail.backgroundColor = .systemTeal
        thumbnail.cornerConfiguration = .corners(radius: .containerConcentric(minimum: DuoTokens.innerRadius))
        contentView.backgroundColor = .secondarySystemGroupedBackground
        [thumbnail, title].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            thumbnail.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            thumbnail.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            thumbnail.widthAnchor.constraint(equalToConstant: 64),
            thumbnail.heightAnchor.constraint(equalToConstant: 64),
            title.leadingAnchor.constraint(equalTo: thumbnail.trailingAnchor, constant: DuoSpace.x3),
            title.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            title.centerYAnchor.constraint(equalTo: thumbnail.centerYAnchor),
            thumbnail.bottomAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.bottomAnchor),
        ])
        apply(DuoTokens(traitCollection))
        registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitPreferredContentSizeCategory.self]) {
            (cell: Self, _: UITraitCollection) in
            cell.apply(DuoTokens(cell.traitCollection))
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func apply(_ tokens: DuoTokens) {
        contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: tokens.cardPadding, leading: tokens.cardPadding,
            bottom: tokens.cardPadding, trailing: tokens.cardPadding)
        contentView.cornerConfiguration = .corners(radius: .fixed(tokens.cardRadius))
    }
}

/// A prominent glass button of at least 44 pt, and an interactive glass panel.
@available(iOS 26.0, *)
@MainActor
func makeGlassControls() -> (UIButton, UIVisualEffectView) {
    var config = UIButton.Configuration.prominentGlass()
    config.image = UIImage(systemName: "play.fill")
    let play = UIButton(configuration: config)
    play.accessibilityLabel = "Play"
    play.widthAnchor.constraint(greaterThanOrEqualToConstant: DuoTokens.minTouchTarget).isActive = true
    play.heightAnchor.constraint(greaterThanOrEqualToConstant: DuoTokens.minTouchTarget).isActive = true

    let effect = UIGlassEffect(style: .regular)
    effect.isInteractive = true
    let panel = UIVisualEffectView(effect: effect)
    panel.cornerConfiguration = .capsule()
    return (play, panel)
}
```

`containerConcentric` makes a corner concentric with the view that contains it ([UICornerConfiguration](https://developer.apple.com/documentation/uikit/uicornerconfiguration-swift.struct)), here the content view with its fixed `cardRadius`. We typechecked this cell but did not render it.

## Grids

`DuoColumns` from [grid.md](grid.md) is plain math. Feed its column frames into a `UICollectionViewCompositionalLayout` section provider: read `traitCollection` for the column count and gutter, and the fold from `view.reservedRegions(kind: .division, options: .includeInactive)` (iOS 27.1). We found no change callback for reserved regions in the UIKit headers; re-query in `viewDidLayoutSubviews` and check in Device Hub that folding triggers a layout pass (unverified).

## Pitfalls

- **`layoutMargins` set to one symmetric value.** On Duo the system margin next to a vertical bar differs from the other side. Change only what you must, per side.
- **`UIFont.systemFont(ofSize:)` for body text.** It ignores Dynamic Type. Use `preferredFont(forTextStyle:)`, or `UIFontMetrics` to scale a custom font.
- **`layer.cornerRadius` near a display edge.** It can't follow the display's curve. Use `cornerConfiguration`.
- **Tokens read once in `viewDidLoad`.** The size class changes every time the phone folds or unfolds. Re-apply on trait changes, as the cell does.
