# Type on both displays

One type scale for the 5.4-inch outer display and the 7.6-inch inner display. Text keeps its size when the phone opens. The inner display uses its extra width for more columns, a second pane and a capped line length, not for bigger letters.

## What Apple asks for

- Use the built-in text styles. They carry size, weight and leading, and they scale with Dynamic Type, including the larger accessibility sizes ([HIG, Typography](https://developer.apple.com/design/human-interface-guidelines/typography#Using-system-fonts)).
- The iOS default text size is 17 pt and the minimum is 11 pt. Avoid the Ultralight, Thin and Light weights for small text ([HIG, Typography](https://developer.apple.com/design/human-interface-guidelines/typography#Ensuring-legibility)).
- Let people enlarge text by at least 200 percent ([HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Vision)).
- At large sizes, stack items that sat side by side, let rows grow, show fewer text columns and truncate as little as possible ([HIG, Typography](https://developer.apple.com/design/human-interface-guidelines/typography#Supporting-Dynamic-Type), [HIG, Layout](https://developer.apple.com/design/human-interface-guidelines/layout#Adaptability)).
- Not every string must grow. Apple's example: people who enlarge text want the content bigger, not the tab titles ([HIG, Typography](https://developer.apple.com/design/human-interface-guidelines/typography#Conveying-hierarchy)).
- On iPhone Duo, Apple asks games to keep text and control sizes as steady as possible while the app resizes ([HIG, Best practices](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Best-practices)). Duology applies that to every app: no font size per display or per size class.
- A custom font must support Dynamic Type and Bold Text like the system font does ([HIG, Typography](https://developer.apple.com/design/human-interface-guidelines/typography#Using-custom-fonts)).

## The roles

`DuoType` in [tokens.md](tokens.md) maps roles to text styles. Sizes in points, from Apple's Dynamic Type tables ([HIG, Specifications](https://developer.apple.com/design/human-interface-guidelines/typography#Specifications)):

| Role | SwiftUI | xSmall | Large (default) | xxxLarge | AX5 (largest) |
|---|---|---|---|---|---|
| `screenTitle` | `.largeTitle.bold()` | 31 | 34 | 40 | 60 |
| `sectionTitle` | `.title2.bold()` | 19 | 22 | 28 | 56 |
| `itemTitle` | `.headline` | 14 | 17 | 23 | 53 |
| `body` | `.body` | 14 | 17 | 23 | 53 |
| `secondary` | `.subheadline` | 12 | 15 | 21 | 49 |
| `meta` | `.footnote` | 12 | 13 | 19 | 44 |
| `caption` | `.caption` | 11 | 12 | 18 | 43 |

The same table applies on both displays. A navigation title from `.navigationTitle` already uses the system style; don't restyle it.

Body text grows almost fourfold from xSmall to AX5. Design the closed outer display at AX5 first: it is the smallest space the app gets (382 × 644 pt of safe area in portrait, *measured* in `duo-setup`), and one half of a stacked split there is about 382 × 321 pt (*measured* in `duo-shared-screen`).

## Line length on the inner display

The inner display's safe area is 867 pt wide held wide (*measured* in `duo-setup`). A single column of body text across it is far too long to read. Cap it with `duoReadableWidth(_:)`. `readableWidth` is 600 pt at the default size and scales with Dynamic Type through `@ScaledMetric`. *Measured* offscreen on the iOS 27.1 simulator runtime: 518 pt at xSmall, 791 pt at xxxLarge, 1309 pt at AX3 and 1691 pt at AX5. At accessibility sizes the cap is wider than any display, so the text uses the full width, which is what large text needs.

```swift
import SwiftUI

// requires: DuoTokens.swift

struct ArticleBody: View {
    let paragraphs: [String]
    @DuoMetrics private var tokens

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DuoSpace.x4) {
                ForEach(paragraphs, id: \.self) { Text($0).font(DuoType.body) }
            }
            .duoReadableWidth(tokens)
            .duoContainerMargins()
        }
    }
}
```

On the inner display the article now sits in a centred column with space on both sides. That space is a good place for a supporting pane (see `duo-patterns`), not for bigger text.

## Stack at accessibility sizes

Rows that put a label and a value side by side run out of room at AX sizes, first on the outer display. Switch the layout, keep the views:

```swift
import SwiftUI

// requires: DuoTokens.swift

struct StatRow: View {
    let title: String
    let value: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DuoSpace.x1))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DuoSpace.x2))
        layout {
            Text(title).font(DuoType.itemTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value).font(DuoType.body).monospacedDigit()
        }
    }
}
```

`AnyLayout` keeps view identity, so nothing resets when the text size changes. `ViewThatFits` works too when you would rather test the space than the setting. For grids, `tokens.span(_:)` already doubles at accessibility sizes ([grid.md](grid.md#spans)).

## Custom fonts

Use `Font.custom(_:size:relativeTo:)`. The size is the size at the default text setting; the text style tells SwiftUI how to scale it ([Applying custom fonts to text](https://developer.apple.com/documentation/swiftui/applying-custom-fonts-to-text)).

```swift
import SwiftUI

nonisolated enum BrandType {
    static let display = Font.custom("Avenir Next", size: 34, relativeTo: .largeTitle)
    static let body = Font.custom("Avenir Next", size: 17, relativeTo: .body)
}
```

Give each brand style the same role and default size as the system style it replaces. Then the table above still holds.

## Sizes that follow text

Spacing and shapes that sit inside text should grow with it. Use `@ScaledMetric(relativeTo:)` for an icon frame next to a label or a minimum tile width. Leave the grid gutter and margins fixed: they belong to the layout, not to the text.

`.dynamicTypeSize(...DynamicTypeSize.accessibility2)` caps the size for one view. Use it only for chrome that would otherwise break and that people don't read for content, such as a segmented control's labels. Never cap body text.

## Pitfalls

- **Bigger fonts on the inner display.** It reads as a stretched phone app. Add columns or a pane instead.
- **`.font(.system(size: 17))`.** A fixed size ignores Dynamic Type. Use a text style, or a custom font with `relativeTo:`.
- **One line of text everywhere.** `.lineLimit(1)` truncates at AX sizes, worst in a closed-phone half. Allow wrapping in scrolling content.
- **Testing only open.** The outer display, held sideways (compact height), is where large text fails first.
- **Light weights.** Thin type gets harder to read through Liquid Glass and in dark mode.

## Test it

Set the text size in Xcode Previews (the Dynamic Type variants) or on the simulator with `xcrun simctl ui <device> content_size accessibility-extra-extra-extra-large` (the largest size; `large` is the default). That command changes the whole simulator: on a shared simulator, set it back to what it was when you finish.

| Text size | Closed, portrait | Closed, sideways | Open, held wide | Open, partly folded |
|---|---|---|---|---|
| xSmall | hierarchy still clear | | lines capped | |
| Large | baseline | baseline | baseline | baseline |
| AX5 | no clipped text, rows stacked | still scrolls, bars not covered | cards on wider spans | nothing in the fold |
