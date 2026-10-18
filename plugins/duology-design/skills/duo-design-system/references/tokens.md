# The token module

One Swift file to copy into the app as `DuoTokens.swift`. It builds for iOS 17 and later. Nothing in it asks which device, display or screen the app runs on: every value comes from the size class and the Dynamic Type size of the view that reads it.

- The first three types (`DuoSpace`, `DuoTokens`, `DuoMetrics`) are the same code as in [SKILL.md](../SKILL.md#1-drop-in-the-token-module).
- The grid helper (`DuoColumns`, `DuoFold`) is a second file: [grid.md](grid.md#the-grid-helper).
- The colour contrast check is a third, optional file: [color.md](color.md#check-contrast-in-code).

*Checked:* this file typechecks with no warnings against the iOS 27.1 simulator SDK in Swift 5 mode, Swift 6 mode, Swift 6 with main actor default isolation (what a new Xcode 27.1 app uses) and with an iOS 17 deployment target. *Measured:* we rendered views that read `@DuoMetrics` offscreen with `ImageRenderer` on the iOS 27.1 simulator runtime. The tokens followed the size class and Dynamic Type size set in the environment, and `readableWidth` scaled from 518 pt (xSmall) to 600 pt (Large), 791 pt (xxxLarge), 1309 pt (AX3) and 1691 pt (AX5).

## DuoTokens.swift

```swift
import SwiftUI

/// Duology's 4-point spacing scale. The suffix is the number of 4-point steps.
nonisolated enum DuoSpace {
    static let x1: CGFloat = 4    // icon to badge, label to value
    static let x2: CGFloat = 8    // related items in a row
    static let x3: CGFloat = 12   // padding around a control with a bezel (HIG)
    static let x4: CGFloat = 16
    static let x5: CGFloat = 20
    static let x6: CGFloat = 24   // padding around a control without a bezel (HIG)
    static let x8: CGFloat = 32
    static let x10: CGFloat = 40
    static let x12: CGFloat = 48
}

/// Design tokens for one view. Read them with `@DuoMetrics`.
nonisolated struct DuoTokens: Equatable, Sendable {
    var isRegularWidth: Bool
    var isAccessibilitySize: Bool
    /// Longest comfortable line of body text, already scaled for Dynamic Type.
    var readableWidth: CGFloat

    init(widthClass: UserInterfaceSizeClass?,
         isAccessibilitySize: Bool = false,
         readableWidth: CGFloat = 600) {
        self.isRegularWidth = widthClass == .regular
        self.isAccessibilitySize = isAccessibilitySize
        self.readableWidth = readableWidth
    }

    /// Layout grid columns. Even in both size classes, so a fold lands in a gutter.
    var columns: Int { isRegularWidth ? 8 : 4 }
    var gutter: CGFloat { isRegularWidth ? DuoSpace.x4 : DuoSpace.x3 }
    var sectionSpacing: CGFloat { isRegularWidth ? DuoSpace.x8 : DuoSpace.x6 }
    var cardPadding: CGFloat { isRegularWidth ? DuoSpace.x5 : DuoSpace.x4 }
    /// Padding plus the inner radius, so nested corners stay concentric.
    var cardRadius: CGFloat { cardPadding + Self.innerRadius }

    /// Grid columns an item spans. Doubles at accessibility text sizes.
    func span(_ base: Int) -> Int { min(columns, isAccessibilitySize ? base * 2 : base) }

    static let minTouchTarget: CGFloat = 44        // HIG
    static let innerRadius: CGFloat = 8            // smallest radius, concentric fallback
    static let clearGlassDimming: Double = 0.35    // HIG, behind clear glass on bright media
}

/// Tokens for the view it sits in: `@DuoMetrics private var tokens`.
@propertyWrapper
struct DuoMetrics: DynamicProperty {
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var readableWidth: CGFloat = 600

    init() {}

    var wrappedValue: DuoTokens {
        DuoTokens(widthClass: widthClass,
                  isAccessibilitySize: typeSize.isAccessibilitySize,
                  readableWidth: readableWidth)
    }
}

/// Text roles. The same on both displays: the inner display shows more, not bigger.
nonisolated enum DuoType {
    static let screenTitle = Font.largeTitle.bold()
    static let sectionTitle = Font.title2.bold()
    static let itemTitle = Font.headline
    static let body = Font.body
    static let secondary = Font.subheadline
    static let meta = Font.footnote
    static let caption = Font.caption
}

/// Semantic colours. System colours already adapt to light, dark and Increase Contrast.
nonisolated enum DuoColor {
    static let background = Color(uiColor: .systemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let separator = Color(uiColor: .separator)

    /// A brand colour with light, dark and increased-contrast variants.
    static func dynamic(light: UIColor, dark: UIColor,
                        lightHighContrast: UIColor? = nil,
                        darkHighContrast: UIColor? = nil) -> Color {
        Color(uiColor: UIColor { traits in
            let high = traits.accessibilityContrast == .high
            if traits.userInterfaceStyle == .dark {
                return high ? (darkHighContrast ?? dark) : dark
            }
            return high ? (lightHighContrast ?? light) : light
        })
    }
}

extension View {
    /// A hit region of at least 44 x 44 pt around any content.
    func duoTouchTarget() -> some View {
        frame(minWidth: DuoTokens.minTouchTarget, minHeight: DuoTokens.minTouchTarget)
            .contentShape(.rect)
    }

    /// System container margins (iOS 27.1). They can differ per side on iPhone Duo.
    /// Same helper as duo-layout's: keep one copy in the app.
    @ViewBuilder
    func duoContainerMargins() -> some View {
        if #available(iOS 27.1, *) {
            contentMargins(for: .container, edges: .horizontal)
        } else {
            padding(.horizontal)
        }
    }

    /// Caps a text column at a readable line length and centres it.
    func duoReadableWidth(_ tokens: DuoTokens) -> some View {
        frame(maxWidth: tokens.readableWidth).frame(maxWidth: .infinity)
    }

    /// Declares a rounded container shape for concentric children.
    /// Both branches read the same, but the compiler binds them to different
    /// overloads. In an app that deploys below iOS 26, only the first branch
    /// reaches the iOS 26 overload that `GeometryProxy.concentricCornerRadii` reads.
    @ViewBuilder
    func duoContainerShape(_ shape: RoundedRectangle) -> some View {
        if #available(iOS 26.0, *) {
            containerShape(shape)
        } else {
            containerShape(shape)
        }
    }
}

/// A content-layer card. Children can use `ConcentricRectangle` to match its corners.
struct DuoCard<Content: View>: View {
    @DuoMetrics private var tokens
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: tokens.cardRadius)
        content
            .padding(tokens.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            // The container shape goes before background(_:in:), or radii read nil.
            .duoContainerShape(shape)
            .background(DuoColor.card, in: shape)
    }
}
```

If the app already has `duoContainerMargins()` from `duo-layout`, delete one of the two copies; they are the same code.

## Every value and where it comes from

"Apple" means the number is on an Apple page. "Duology default" means Apple gives no number and we picked one; change it to fit your brand, but keep the rule next to it.

| Token | Compact width | Regular width | Source |
|---|---|---|---|
| `DuoSpace` steps | 4, 8, 12, 16, 20, 24, 32, 40, 48 | same | Duology default: a 4-point scale. Apple's own spacing numbers (12 and 24 pt of padding around controls, 16 to 20 pt margins, 44 pt targets) all sit on it. |
| Margins | system container margins | system container margins | Apple: [`ContentMarginGuide.container`](https://developer.apple.com/documentation/swiftui/contentmarginguide/container) gives 16 to 20 pt on iPhone and can differ per side on iPhone Duo. Not measured on Duo yet. |
| `columns` | 4 | 8 | Duology default. The rule (even counts where a fold can cross) is Apple's: [HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions), [111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=456). |
| `gutter` | 12 | 16 | Duology default. |
| Gutter at the fold | none | flat: `gutter`; partly folded: the fold's frame | Apple's Fitness example widens the gap at the hinge and keeps the outer margins ([111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=350)). |
| `sectionSpacing` | 24 | 32 | Duology default. |
| `cardPadding` | 16 | 20 | Duology default. |
| `cardRadius` | 24 | 28 | Derived: `cardPadding + innerRadius`. *Measured:* a child inset 16 pt in a 24 pt container, or 20 pt in a 28 pt one, gets an 8 pt concentric radius. |
| `innerRadius` | 8 | 8 | Duology default. |
| `minTouchTarget` | 44 | 44 | Apple: [HIG, Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons). |
| `clearGlassDimming` | 0.35 | 0.35 | Apple: [HIG, Materials](https://developer.apple.com/design/human-interface-guidelines/materials#Liquid-Glass). |
| `readableWidth` | 600 pt at the default text size, scaled | same | Duology default, about 70 characters of body text. UIKit's [`readableContentGuide`](https://developer.apple.com/documentation/uikit/uiview/readablecontentguide) does the same job and gives no number. |
| `span(_:)` | doubles at accessibility sizes | same | Apple asks for fewer columns at large text sizes ([HIG, Typography](https://developer.apple.com/design/human-interface-guidelines/typography#Supporting-Dynamic-Type)). |
| `DuoType` | system text styles | same styles | Apple: [HIG, Typography](https://developer.apple.com/design/human-interface-guidelines/typography). |
| `DuoColor` | system semantic colours | same | Apple: [HIG, Color](https://developer.apple.com/design/human-interface-guidelines/color). |

Why size class and not width: Apple asks for two layouts, compact width for the outer display and regular width for the inner display, and warns against breakpoints and metrics tied to one screen ([111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=230), [HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Device-poses)). The size class is that switch. Where a view needs to know its real width, as a grid does, it measures its own box ([grid.md](grid.md)).

## Reading tokens

- In a SwiftUI view: `@DuoMetrics private var tokens`. It reads the size class where the view sits, so a view inside an `ArrangementView` half gets compact tokens on the inner display (`duo-layout` measured compact width in a side-by-side half).
- In plain code that has no view (tests, layout math): `DuoTokens(widthClass: .regular)`.
- In UIKit: `DuoTokens(traitCollection)`; see [uikit.md](uikit.md).
- A `nil` size class gives compact tokens. That is the safe side: fewer columns, smaller gaps.

## Checks you can run on the Mac

The tokens are plain values, so a few assertions catch accidental edits. We ran these against the module on the iOS 27.1 simulator runtime (as a command-line tool with `xcrun simctl spawn`, which shows no UI); all passed.

```swift
// requires: DuoTokens.swift

func checkTokens() -> Bool {
    let compact = DuoTokens(widthClass: .compact)
    let regular = DuoTokens(widthClass: .regular)
    let large = DuoTokens(widthClass: .compact, isAccessibilitySize: true)
    return compact.columns % 2 == 0 && regular.columns % 2 == 0     // even grids
        && compact.cardRadius - compact.cardPadding == DuoTokens.innerRadius
        && regular.cardRadius - regular.cardPadding == DuoTokens.innerRadius
        && large.span(2) == 4 && large.span(4) == compact.columns  // capped at the grid
        && DuoTokens(widthClass: nil).columns == compact.columns
}
```

## Changing the values

- Keep both column counts even. Odd counts put a tile in the fold when the phone is partly open.
- Keep `cardRadius = cardPadding + innerRadius`. If you change one, the others follow, and nested corners stay concentric.
- Keep `minTouchTarget` at 44 or more.
- Don't add a font size per size class. Apple's text styles already scale with Dynamic Type; the inner display gets more columns and a capped line length instead.
- Don't add a token per display ("outerMargin", "innerMargin"). If two values differ, they differ by size class or by the view's own width.

## From a design file

Designers often hand over two frames, one per display, with fixed numbers. Map them like this:

| In the file | In code |
|---|---|
| Margins of 16 and 20 | `duoContainerMargins()`; the system picks the value and the side |
| A 12-column grid on the open phone | `columns` 8 (or 12, also even) on regular width |
| Font sizes that differ between the two frames | One `DuoType` role; explain that Dynamic Type sets the size |
| A fixed card width | A column span (`tokens.span(2)`) |
| A corner radius on an element at the screen edge | `ConcentricRectangle`; see [corners.md](corners.md) |
| A glass panel behind content | Glass on controls only; see [liquid-glass.md](liquid-glass.md) |
