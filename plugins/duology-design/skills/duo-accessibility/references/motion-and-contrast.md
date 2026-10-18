# Reduce Motion, contrast and transparency

The settings that change how things move and look. `duo-transitions` owns the resize animation itself, `duo-postures` owns hinge effects, and `duo-design-system` owns the colour tokens. This file gives the accessibility rules they share.

## Reduce Motion

With Reduce Motion on, Apple asks apps to cut automatic and repeating animation, zooming, scaling and peripheral motion. It suggests tighter springs, motion that tracks the finger, no depth or blur animation, and fades instead of slides ([HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Cognitive)).

| Read it | SwiftUI | UIKit |
|---|---|---|
| Reduce Motion | [`accessibilityReduceMotion`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion) | [`UIAccessibility.isReduceMotionEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isreducemotionenabled), `reduceMotionStatusDidChangeNotification` |
| Prefer Cross-Fade Transitions | [`accessibilityPrefersCrossFadeTransitions`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityprefersCrossFadeTransitions) (iOS 26.4) | [`UIAccessibility.prefersCrossFadeTransitions`](https://developer.apple.com/documentation/uikit/uiaccessibility/preferscrossfadetransitions) (iOS 14) |

Both cross-fade values are true only when Reduce Motion and Prefer Cross-Fade Transitions are both on.

### What it means on iPhone Duo

| Motion | With Reduce Motion |
|---|---|
| Hinge effects (parallax, zoom, tilt that follow the angle) | Off. Reset the value at once. |
| Panes that slide in on unfold | Fade in, or appear. |
| Content that zooms or flies to its new place on resize | Takes its new place at once, or fades. |
| A grid that animates its column change | No movement. |
| A hinge "input" (a value the fold drives) | Keep the on-screen control; hinge input stays opt-in. |

### Hinge effect

```swift
import SwiftUI

@available(iOS 27.1, *)
struct HingeGlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = 0.0

    var body: some View {
        Circle()
            .fill(.orange.gradient)
            .scaleEffect(reduceMotion ? 1 : 1 + glow * 0.08)   // resets at once when the setting turns on
            .accessibilityHidden(true)                          // decoration only
            .onHingeChange(isEnabled: !reduceMotion) { _, new in
                guard let hinge = new.hinge, hinge.status == .partiallyOpen else { glow = 0; return }
                glow = 1 - hinge.angle.degrees / 180
            }
    }
}
```

- `onHingeChange(isEnabled:_:)` stops calling you when disabled, so reset in the view, not in the handler ([doc](https://developer.apple.com/documentation/swiftui/view/onhingechange(isenabled:_:))).
- `hinge` is nil where no hinge reports, so the effect stays at rest on other iPhones.

### Panes and resize

```swift
import SwiftUI

struct SupportingPaneStack<Main: View, Pane: View>: View {
    @ViewBuilder var main: Main
    @ViewBuilder var pane: Pane
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            main.frame(maxWidth: .infinity)
            if widthClass == .regular {
                pane
                    .frame(width: 320)
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth, value: widthClass)
    }
}
```

The short ease under Reduce Motion animates only the fade; nothing travels. For the finer setting, read `accessibilityPrefersCrossFadeTransitions` behind `if #available(iOS 26.4, *)`.

### UIKit

```swift
import UIKit

@available(iOS 27.1, *)
final class HingeArtworkView: UIView {
    private var interaction: UIHingeInteraction?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false   // decoration
        let hinge = UIHingeInteraction { [weak self] _, update in
            guard let self, let hinge = update.hinge, hinge.status == .partiallyOpen else {
                self?.transform = .identity
                return
            }
            let amount = 1 - hinge.angle / .pi              // UIKit gives radians
            self.transform = CGAffineTransform(scaleX: 1 + amount * 0.08, y: 1 + amount * 0.08)
        }
        addInteraction(hinge)
        interaction = hinge
        applyReduceMotion()
        NotificationCenter.default.addObserver(self, selector: #selector(applyReduceMotion),
                                               name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func applyReduceMotion() {
        let reduce = UIAccessibility.isReduceMotionEnabled
        interaction?.isEnabled = !reduce
        if reduce { transform = .identity }
    }
}
```

## Increase Contrast

- Read `@Environment(\.colorSchemeContrast)`; it is `.increased` when the setting is on ([doc](https://developer.apple.com/documentation/swiftui/environmentvalues/colorschemecontrast)). UIKit: `traitCollection.accessibilityContrast == .high` ([doc](https://developer.apple.com/documentation/uikit/uitraitcollection/accessibilitycontrast)).
- System colours adapt on their own. Custom colours need High Contrast variants in the asset catalog, or `DuoColor.dynamic(...)` from `duo-design-system`.
- Minimum ratios: 4.5:1 for text up to 17 pt, 3:1 at 18 pt or bold ([HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Vision)). If the default look can't meet them, the Increase Contrast look must.
- *Measured* by the audit on the closed display: `Color(white: 0.85)` text on white failed; `.secondary` text and a tinted button title "nearly passed". `duo-design-system` measured `secondaryLabel` at 3.44:1 in light mode: fine for large text, not for small body text.

Where a pane edge or the fold gap is drawn with a faint line, strengthen it:

```swift
import SwiftUI

struct PaneSeparator: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Rectangle()
            .fill(contrast == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(.separator))
            .frame(width: contrast == .increased ? 2 : 1)
            .accessibilityHidden(true)
    }
}
```

## Reduce Transparency

- With Reduce Transparency on, the vertical bar gets a background ([talk 111462](https://developer.apple.com/videos/play/tech-talks/111462/?time=652)). Custom views inside it must read on glass and on that background.
- For your own materials and glass over content, read `accessibilityReduceTransparency` and use an opaque background when it is on ([doc](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency)). Liquid Glass rules: `duo-design-system`.

## Differentiate Without Color

Selection, the active pane and errors need a second signal besides colour ([HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Vision)). Add the `.isSelected` trait so VoiceOver says it too.

```swift
import SwiftUI

struct PaneRow: View {
    let title: String
    let isSelected: Bool
    @Environment(\.accessibilityDifferentiateWithoutColor) private var noColor

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if isSelected && noColor {
                Image(systemName: "checkmark").accessibilityHidden(true)  // the trait already says it
            }
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.18) : .clear, in: .rect(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
```

## Test the settings

| Setting | How to turn it on in the simulator |
|---|---|
| Increase Contrast | `xcrun simctl ui <UDID> increase_contrast enabled` |
| Dark appearance | `xcrun simctl ui <UDID> appearance dark` |
| Reduce Motion, Reduce Transparency, Differentiate Without Color, Button Shapes, Bold Text | Accessibility Inspector, Settings pane, or the simulator's Settings app ([doc](https://developer.apple.com/documentation/accessibility/testing-system-accessibility-features-in-your-app)) |

*Measured:* with Increase Contrast on and an accessibility text size set, the probe app read `colorSchemeContrast == .increased` and `dynamicTypeSize == .accessibility3`. Turn each setting off again on a shared simulator.
