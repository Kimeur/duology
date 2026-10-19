# Colour and contrast in light and dark

Colours don't change between the two displays. They change with the appearance (light or dark) and with Increase Contrast. This file covers semantic colours, custom brand colours, the contrast numbers to meet and a check you can run.

## What Apple asks for

- Prefer system colours. They have light, dark and increased-contrast variants built in, and they adapt to vibrancy ([HIG, Color](https://developer.apple.com/design/human-interface-guidelines/color#Best-practices)).
- Use dynamic colours for what they mean: background levels for backgrounds, label colours for text, separator for separators. Don't repurpose one as another ([HIG, Color](https://developer.apple.com/design/human-interface-guidelines/color#System-colors)).
- Don't hard-code the values of system colours. They can change between releases ([HIG, Color](https://developer.apple.com/design/human-interface-guidelines/color#System-colors)).
- Give every custom colour a light and a dark variant, plus an increased-contrast version of each. Do it even if the app has one appearance, because Liquid Glass adapts between them ([HIG, Color](https://developer.apple.com/design/human-interface-guidelines/color#Best-practices)).
- Contrast minimums, from WCAG AA as Accessibility Inspector applies them ([HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Vision)):

  | Text | Minimum contrast |
  |---|---|
  | Up to 17 pt, any weight | 4.5:1 |
  | 18 pt and larger | 3:1 |
  | Bold, any size | 3:1 |

- For custom text and background colours, aim for 7:1, above all for small text ([HIG, Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode#Dark-Mode-colors)). If the default colours can't meet the minimum, at least meet it when Increase Contrast is on ([HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Vision)).
- Never carry meaning in colour alone. Add a symbol, a shape or a label ([HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Vision)).
- Check both appearances with Increase Contrast and Reduce Transparency on, alone and together ([HIG, Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode#Best-practices)). Don't offer an in-app appearance switch ([HIG, Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode#Best-practices)).

## The semantic set

`DuoColor` in [tokens.md](tokens.md) names the backgrounds. Use SwiftUI's foreground styles for text.

| Use | SwiftUI | UIKit |
|---|---|---|
| Screen background | `DuoColor.background` | `.systemBackground` |
| Grouped screen background | `DuoColor.groupedBackground` | `.systemGroupedBackground` |
| Card on a grouped background | `DuoColor.card` | `.secondarySystemGroupedBackground` |
| Primary text | `.foregroundStyle(.primary)` | `.label` |
| Supporting text | `.foregroundStyle(.secondary)` | `.secondaryLabel` |
| Separator | `DuoColor.separator` | `.separator` |
| Tint, links, selected state | `.tint`, `Color.accentColor` | `tintColor`, `.link` |

Put `DuoCard` (`DuoColor.card`) on `DuoColor.groupedBackground`, never on `DuoColor.background`. *Measured* on the iOS 27.1 simulator runtime in light mode: `secondarySystemGroupedBackground` and `systemBackground` are both pure white, so a card on a plain background has no visible edge. `systemGroupedBackground` is a light grey (0.949, 0.949, 0.969). In dark mode the card is the lighter one (0.110 grey on black).

## Measured contrast of system colours

We resolved each colour for light, dark and Increase Contrast with `UIColor.resolvedColor(with:)`, composited translucent colours over the background, and computed the WCAG ratio, on the iOS 27.1 simulator runtime (the check below, run with `xcrun simctl spawn`):

| Text on background | Light | Light + Increase Contrast | Dark | Dark + Increase Contrast |
|---|---|---|---|---|
| `label` on `systemBackground` | 21.0 | 21.0 | 21.0 | 21.0 |
| `label` on `secondarySystemGroupedBackground` | 21.0 | 21.0 | 17.0 | 15.5 |
| `secondaryLabel` on `systemBackground` | 3.44 | 5.97 | 6.36 | 8.48 |
| `secondaryLabel` on `secondarySystemGroupedBackground` | 3.44 | 5.97 | 5.95 | 7.10 |
| `secondaryLabel` on `systemGroupedBackground` | 3.30 | 5.33 | 6.36 | 8.48 |
| `tertiaryLabel` on `systemBackground` | 1.73 | 4.46 | 2.23 | 5.42 |
| `link` on `systemBackground` | 4.02 | 4.02 | 5.76 | 5.76 |
| `systemBlue` on `systemBackground` | 3.52 | 4.57 | 6.49 | 9.76 |

What follows from it:

- `label` passes everywhere. Use it for essential text at any size.
- `secondaryLabel` and `systemBlue` (the default tint) pass 3:1 in light mode but not 4.5:1. They pass 4.5:1 with Increase Contrast on, which is the fallback Apple accepts. Use them for text of 18 pt or more, bold text, symbols and controls. For small, regular-weight text that people must read, prefer `label`.
- `tertiaryLabel` is for decoration and disabled states, not for information.
- These are today's values. Apple may change them in any release; re-run the check after an Xcode update.

## Custom colours

Prefer an asset catalog colour set with Any, Dark and High Contrast appearances. When colours live in code, use `DuoColor.dynamic`:

```swift
import SwiftUI

// requires: DuoTokens.swift

extension DuoColor {
    /// Brand accent: deep enough for text on white, light enough for text on black.
    static let brand = DuoColor.dynamic(
        light: UIColor(red: 0.00, green: 0.38, blue: 0.75, alpha: 1),
        dark: UIColor(red: 0.45, green: 0.72, blue: 1.00, alpha: 1),
        lightHighContrast: UIColor(red: 0.00, green: 0.28, blue: 0.58, alpha: 1),
        darkHighContrast: UIColor(red: 0.65, green: 0.83, blue: 1.00, alpha: 1))
}
```

Then check it.

## Check contrast in code

`Contrast.swift`, a third file next to `DuoTokens.swift`. It typechecks against the iOS 27.1 simulator SDK in Swift 5, Swift 6 and main actor default isolation modes. The numbers in the table above came from it.

```swift
import UIKit

/// An sRGB colour with components and alpha from 0 to 1.
nonisolated struct DuoRGB: Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    /// This colour drawn over an opaque background.
    func over(_ background: DuoRGB) -> DuoRGB {
        func mix(_ top: Double, _ bottom: Double) -> Double { top * alpha + bottom * (1 - alpha) }
        return DuoRGB(red: mix(red, background.red), green: mix(green, background.green),
                      blue: mix(blue, background.blue))
    }

    /// WCAG relative luminance of the opaque colour.
    var luminance: Double {
        func linear(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio of this colour drawn on `background`, from 1 to 21.
    func contrast(on background: DuoRGB) -> Double {
        let top = over(background).luminance
        let bottom = background.luminance
        return (max(top, bottom) + 0.05) / (min(top, bottom) + 0.05)
    }
}

@MainActor
extension DuoRGB {
    /// Resolves a dynamic colour for one appearance and reads its sRGB values.
    /// Wide-colour values outside sRGB are clamped.
    init(_ color: UIColor, dark: Bool, highContrast: Bool = false) {
        let traits = UITraitCollection { traits in
            traits.userInterfaceStyle = dark ? .dark : .light
            traits.accessibilityContrast = highContrast ? .high : .normal
        }
        var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        color.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        func clamp(_ v: CGFloat) -> Double { Double(min(max(v, 0), 1)) }
        self.init(red: clamp(r), green: clamp(g), blue: clamp(b), alpha: clamp(a))
    }
}

/// The lowest contrast of a text colour on an opaque background, across light,
/// dark and Increase Contrast. Needs 4.5 for text up to 17 pt, 3 for 18 pt and up or bold.
@MainActor
func duoWorstContrast(text: UIColor, on background: UIColor) -> Double {
    var worst = Double.infinity
    for dark in [false, true] {
        for high in [false, true] {
            let ratio = DuoRGB(text, dark: dark, highContrast: high)
                .contrast(on: DuoRGB(background, dark: dark, highContrast: high))
            worst = min(worst, ratio)
        }
    }
    return worst
}
```

Use it in a test (Swift Testing) for every text and background pair your design uses:

```swift
import Testing
import UIKit

// requires: Contrast.swift, DuoTokens.swift (for DuoColor.brand above)

@MainActor
struct ColorContrastTests {
    @Test func bodyTextPairs() {
        #expect(duoWorstContrast(text: .label, on: .systemBackground) >= 4.5)
        #expect(duoWorstContrast(text: .label, on: .secondarySystemGroupedBackground) >= 4.5)
    }

    @Test func brandOnBackground() {
        let brand = UIColor(DuoColor.brand)
        #expect(duoWorstContrast(text: brand, on: .systemBackground) >= 4.5)
    }
}
```

The check covers the four combinations of appearance and contrast. It treats the background as opaque. For text on glass or a material, check a screenshot with Accessibility Inspector, which applies the same WCAG values ([HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Vision)).

## On iPhone Duo

- Use the same colours on both displays and in every pose. Only the appearance and the contrast setting change them.
- When the inner display shows two panes, separate them with the system split view or with background levels (`systemBackground` beside `secondarySystemBackground`), not with a brand colour.
- Colourful content scrolls under the vertical bar's glass. At rest, the top of a scroll view should keep the bar's symbols readable ([HIG, Color](https://developer.apple.com/design/human-interface-guidelines/color#Liquid-Glass-color)).
- Status the user must notice (an error, a live recording) needs a symbol or text as well as colour, in every half of a split screen.

## Pitfalls

- **Grey text that passes in dark mode only.** Check light mode first; the measured `secondaryLabel` ratios are lowest there.
- **A hex value copied from a design tool.** It has no dark or high-contrast variant.
- **Blue body text in light mode.** The default tint reads 3.52:1 on white. Fine for a bold button title, too low for a paragraph link.
- **Off-white backgrounds behind white cards.** The card disappears. Use the grouped background levels, which Apple tuned for this.
- **Checking contrast on one display only.** The colours are the same, but the backgrounds behind glass differ with layout. Check a screenshot of each display.
