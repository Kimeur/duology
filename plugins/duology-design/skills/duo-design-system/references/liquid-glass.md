# Liquid Glass on iPhone Duo

Liquid Glass is the material of the controls layer since iOS 26, and it carries into iOS 27. On iPhone Duo the system already draws a lot of it: the vertical bar that holds the toolbar and tab bar, sheets, menus, alerts. Most apps need little custom glass. This file says where custom glass goes, which variant to use and how to keep text on it readable.

The APIs below are iOS 26.0 and later: `glassEffect(_:in:)`, `Glass` (`.regular`, `.clear`, `tint(_:)`, `interactive(_:)`), `GlassEffectContainer`, the `.glass` and `.glassProminent` button styles, and `scrollEdgeEffectStyle(_:for:)`. Apple's guide: [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views).

## Where glass goes

- **Controls and navigation only.** Glass marks the layer that floats above content. Don't use it for cards, list rows or backgrounds; use the standard materials or plain colours there ([HIG, Materials](https://developer.apple.com/design/human-interface-guidelines/materials#Liquid-Glass), [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/?time=784)).
- **Sparingly.** Standard bars and buttons get glass on their own. Add it to custom controls only for the few that matter most ([HIG, Materials](https://developer.apple.com/design/human-interface-guidelines/materials#Liquid-Glass)).
- **Never glass on glass.** For an element on top of glass, use fills, transparency or vibrancy, not a second layer of glass ([Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/?time=804)).
- **Group nearby glass.** Put custom glass elements that sit near each other in one `GlassEffectContainer`. Glass can't sample other glass, so separate containers render inconsistently ([Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/?time=1196)).
- **No solid strips under controls.** Use the scroll edge effect instead of a coloured or blurred band behind a bar, and remove backgrounds you added behind bar items ([HIG, Layout](https://developer.apple.com/design/human-interface-guidelines/layout#Visual-hierarchy), [Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/?time=633)).

## Regular or clear

| | `.regular` | `.clear` |
|---|---|---|
| Looks | Blurs and adjusts what's behind it to keep text readable | Very transparent; the content behind stays vivid |
| Use for | Almost everything, and anything with much text | Small controls over photos and video only |
| Text on it | Readable over any content; the system flips symbols and text between light and dark | Needs a dimming layer behind it |
| Mix with the other | No | No |

Sources: [HIG, Materials](https://developer.apple.com/design/human-interface-guidelines/materials#Liquid-Glass), [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/?time=831).

Use clear glass only when all three hold: the element sits over media, a dimming layer won't hurt that media, and the content on the glass is bold and bright ([Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/?time=886)). Over bright media, put a black layer at 35% opacity behind the glass (`DuoTokens.clearGlassDimming`). Over dark media, or behind AVKit's own player controls, skip it ([HIG, Materials](https://developer.apple.com/design/human-interface-guidelines/materials#Liquid-Glass), [`Glass.clear`](https://developer.apple.com/documentation/swiftui/glass/clear)).

## Tint and colour

- Tint only the primary action, and tint its background rather than its symbol or label ([HIG, Color](https://developer.apple.com/design/human-interface-guidelines/color#Liquid-Glass-color)). One or two prominent buttons per view at most ([HIG, Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons#Style)).
- When everything is tinted, nothing stands out. Put brand colour in the content layer instead ([Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/?time=1049)).
- Over colourful content, keep control labels monochrome ([HIG, Color](https://developer.apple.com/design/human-interface-guidelines/color#Liquid-Glass-color)).
- At rest (a screen just opened, scrolled to the top), content should not sit under glass controls. Leave space, or move or scale the content ([Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/?time=1074)).
- Supply light and dark variants of custom colours even if the app has one appearance, because glass adapts between them ([HIG, Color](https://developer.apple.com/design/human-interface-guidelines/color#Best-practices)).

## On iPhone Duo

- **The vertical bar is already glass.** On the outer display, and on the inner display in landscape, the system puts the toolbar and tab bar in one bar on the side ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls)). Don't add a custom glass strip next to it, and don't add spacing inside it ([111462](https://developer.apple.com/videos/play/tech-talks/111462/?time=676)).
- **Let backgrounds run under the bar.** Full-bleed art goes under bars with `.ignoresSafeArea()` or `backgroundExtensionEffect()`; controls and text stay in the safe area ([111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=419)).
- **Legible with and without a background.** A vertical bar has no scroll edge effect by default, and it gets a solid background when Reduce Transparency is on. A custom view inside it must read well in both states ([111462](https://developer.apple.com/videos/play/tech-talks/111462/?time=652)).
- **Floating glass follows the fold rules.** A custom glass control you place near the middle must move off the fold when the phone is partly open, like any control. Use the displacement code in `duo-layout` (`FoldAvoidingControls`). Keep it clear of the camera occlusion regions too.
- **Same glass on both displays.** Don't swap regular for clear, or add tint, when the phone opens. Change position and size; keep the material.

## Accessibility settings

System glass adapts on its own: Reduce Transparency makes it frostier, Increase Contrast makes elements mostly black or white with a border, and Reduce Motion tones down its effects ([Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/?time=1102)). People can also choose a preferred look for Liquid Glass in Settings ([HIG, Materials](https://developer.apple.com/design/human-interface-guidelines/materials#Liquid-Glass)). Check custom glass with each setting on. A custom translucent surface that is not glass should turn opaque when `accessibilityReduceTransparency` is true ([doc](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency)).

## Code

Typechecked against the iOS 27.1 simulator SDK in Swift 5, Swift 6 and main actor default isolation modes, and with an iOS 17 deployment target (the glass views carry `@available(iOS 26.0, *)`).

A floating group of custom glass buttons. One prominent action, the others plain glass, all in one container, each at least 44 pt:

```swift
import SwiftUI

// requires: DuoTokens.swift

@available(iOS 26.0, *)
struct PlayerControls: View {
    @Binding var isPlaying: Bool

    var body: some View {
        GlassEffectContainer(spacing: DuoSpace.x3) {
            HStack(spacing: DuoSpace.x3) {
                Button {
                } label: {
                    Label("Back 15 Seconds", systemImage: "gobackward.15")
                        .labelStyle(.iconOnly)
                        .duoTouchTarget()
                }
                .buttonStyle(.glass)

                Button {
                    isPlaying.toggle()
                } label: {
                    Label(isPlaying ? "Pause" : "Play",
                          systemImage: isPlaying ? "pause.fill" : "play.fill")
                        .labelStyle(.iconOnly)
                        .duoTouchTarget()
                }
                .buttonStyle(.glassProminent)   // the one tinted, primary action

                Button {
                } label: {
                    Label("Forward 15 Seconds", systemImage: "goforward.15")
                        .labelStyle(.iconOnly)
                        .duoTouchTarget()
                }
                .buttonStyle(.glass)
            }
            .buttonBorderShape(.circle)
        }
    }
}
```

Keep the container's spacing equal to the stack's spacing. A larger container spacing makes the shapes blend together at rest ([Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)).

Clear glass over a photo, with the dimming layer behind it:

```swift
import SwiftUI

// requires: DuoTokens.swift

@available(iOS 26.0, *)
struct PhotoCaptionBadge: View {
    let caption: String

    var body: some View {
        Text(caption)
            .font(DuoType.itemTitle)
            .padding(.horizontal, DuoSpace.x4)
            .padding(.vertical, DuoSpace.x2)
            .glassEffect(.clear, in: .capsule)
            .background(.black.opacity(DuoTokens.clearGlassDimming), in: .capsule)
    }
}
```

A custom interactive control that is glass, tinted only while selected:

```swift
import SwiftUI

// requires: DuoTokens.swift

@available(iOS 26.0, *)
struct FilterChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(DuoType.secondary)
            .padding(.horizontal, DuoSpace.x3)
            .frame(minHeight: DuoTokens.minTouchTarget)
            .glassEffect(isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                         in: .capsule)
    }
}
```

Put a row of these chips in a `GlassEffectContainer` too.

A translucent surface that is not glass, and turns opaque with Reduce Transparency:

```swift
import SwiftUI

// requires: DuoTokens.swift

struct Toast: View {
    let message: String
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Text(message)
            .font(DuoType.body)
            .padding(DuoSpace.x4)
            .background {
                if reduceTransparency {
                    Capsule().fill(DuoColor.card)
                } else {
                    Capsule().fill(.regularMaterial)
                }
            }
    }
}
```

The scroll edge effect, set per edge, instead of a solid band behind controls:

```swift
import SwiftUI

// requires: DuoTokens.swift

@available(iOS 26.0, *)
struct EdgeEffectList: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DuoSpace.x2) {
                ForEach(0..<50, id: \.self) { Text("Row \($0)") }
            }
            .duoContainerMargins()
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
```

UIKit versions (`UIGlassEffect`, `UIButton.Configuration.glass()`) are in [uikit.md](uikit.md).

## Pitfalls

- **Glass cards in a list.** Content in glass competes with the controls. Use `DuoCard` (a plain grouped background) for content.
- **A glass panel behind the vertical bar's neighbour.** Two glass layers side by side read as one cluttered strip.
- **Clear glass over a white photo without dimming.** White text disappears.
- **Tinting every button.** Keep one prominent action per view.
- **A custom dark band under the top of a scroll view.** It fights the scroll edge effect. Remove it.
- **Glass controls in the fold.** System controls move; yours don't unless you move them.
