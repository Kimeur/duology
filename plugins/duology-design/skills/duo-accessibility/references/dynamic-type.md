# Dynamic Type on both displays

The text size is one setting for the whole phone. The room for text is not: the closed outer display gives a screen 382 pt wide inside its safe area, the open inner display about 950 pt (*measured* by `duo-design-system` and `duo-patterns`). A layout that reads well open can clip closed at the same size. Apple wants text enlargeable by at least 200 percent, as much text visible at the largest accessibility size as at the largest standard size, and stacked layouts when inline items crowd the text ([HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Vision), [HIG, Typography](https://developer.apple.com/design/human-interface-guidelines/typography#Supporting-Dynamic-Type)).

## Sizes and names

| Settings name | `DynamicTypeSize` | `xcrun simctl ui <UDID> content_size` |
|---|---|---|
| Large (default) | `.large` | `large` |
| Largest standard | `.xxxLarge` | `extra-extra-extra-large` |
| Largest accessibility (AX5) | `.accessibility5` | `accessibility-extra-extra-extra-large` |

- `isAccessibilitySize` is true for the five accessibility sizes, `.accessibility1` to `.accessibility5` ([doc](https://developer.apple.com/documentation/swiftui/dynamictypesize/isaccessibilitysize)).
- The `simctl` values come from `xcrun simctl ui` help; the table matches them to `DynamicTypeSize` by name.
- For one test run, use a launch argument instead: it reaches only that launch of your app, so other apps on a shared simulator keep their size. *Measured:* `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` gave the app `.accessibility5`.

## Reflow recipes

### A row that stacks

The row in SKILL.md switches from `HStackLayout` to `VStackLayout` with `AnyLayout` at accessibility sizes. *Measured* closed: 348 × 42 pt at Large, 297 × 370 pt at AX5, no audit issues. The same row with `lineLimit(1)` and `frame(height: 30)` got "Text clipped" twice.

### A strip of controls

`ViewThatFits` tries each child in order and shows the first that fits the space ([doc](https://developer.apple.com/documentation/swiftui/viewthatfits)). Good for a strip that must work in a 382 pt outer display at AX5 and beside a pane on the inner display.

```swift
import SwiftUI

struct PlaybackStrip: View {
    let play: () -> Void
    let skip: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {                       // titles and icons
                Button("Play", systemImage: "play.fill", action: play)
                Button("Skip 15 Seconds", systemImage: "goforward.15", action: skip)
            }
            HStack(spacing: 16) {                       // icons only; titles stay for VoiceOver
                Button("Play", systemImage: "play.fill", action: play)
                Button("Skip 15 Seconds", systemImage: "goforward.15", action: skip)
            }
            .labelStyle(.iconOnly)
        }
    }
}
```

### A grid with fewer, wider columns

Scale the minimum column width with the text. At accessibility sizes the grid then drops columns on its own, on both displays.

```swift
import SwiftUI

struct PhotoGrid: View {
    let titles: [String]
    @ScaledMetric(relativeTo: .body) private var minColumn = 160.0

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minColumn), spacing: 12)], spacing: 12) {
                ForEach(titles, id: \.self) { title in
                    VStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 12).fill(.quaternary).aspectRatio(4 / 3, contentMode: .fit)
                        Text(title)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding()
        }
    }
}
```

When a fold crosses the grid, `duo-patterns` (feed reflow) and `duo-design-system` (`span`) keep the column count even. Combine both: scale the width, then round the count down to an even number.

### Two panes at large sizes

- Each half of the open display is wider than the closed display (about 455 pt against 382 pt, *derived* from the 951 pt window and the 40 pt fold region). A pane that works closed at AX5 fits in a half.
- A sidebar column is narrower than a half. Check the `NavigationSplitView` sidebar at AX5; rows must wrap, not clip.
- Keep both panes at large sizes. Removing a pane removes a feature, and Apple asks for the same features closed and open (`duo-patterns`).

## Things that can't grow

Some chrome has a fixed size, such as custom views in a vertical bar, which must fit the bar's fixed width ([talk 111462](https://developer.apple.com/videos/play/tech-talks/111462/?time=611)). Give them a large content view: people at accessibility sizes press and hold to see a big copy. Apple reserves this for items that must stay small, like tab bar buttons ([doc](https://developer.apple.com/documentation/uikit/uilargecontentviewerinteraction)).

```swift
import SwiftUI

struct ComposeBarButton: View {
    let compose: () -> Void

    var body: some View {
        Button(action: compose) {
            Image(systemName: "square.and.pencil")
        }
        .accessibilityLabel("New Message")
        .accessibilityShowsLargeContentViewer {
            Label("New Message", systemImage: "square.and.pencil")
        }
    }
}
```

Don't cap the text size of content with `dynamicTypeSize(...)`. Cap it only on such fixed chrome, and add the large content view when you do.

## UIKit

```swift
import UIKit

final class MessageCell: UITableViewCell {
    private let subject = UILabel()
    private let date = UILabel()
    private let stack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        for (label, style) in [(subject, UIFont.TextStyle.body), (date, .subheadline)] {
            label.font = .preferredFont(forTextStyle: style)
            label.adjustsFontForContentSizeCategory = true   // follows the setting live
            label.numberOfLines = 0                          // wrap, never truncate
        }
        stack.addArrangedSubview(subject)
        stack.addArrangedSubview(date)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
        ])
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: MessageCell, _) in
            cell.updateAxis()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Side by side at standard sizes, stacked at accessibility sizes.
    private func updateAxis() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        stack.axis = large ? .vertical : .horizontal
        stack.alignment = large ? .leading : .firstBaseline
        stack.spacing = UIFontMetrics(forTextStyle: .body).scaledValue(for: large ? 4 : 8)
    }
}
```

## What to test

1. The closed outer display at AX5 first, portrait and landscape. Landscape is compact height, so a stacked layout needs to scroll.
2. Open at AX5: each pane, the sidebar, and Split View (half the inner display).
3. Largest standard size (`xxxLarge`) on both, because it is the most common large size.
4. Bold Text on (Accessibility Inspector's Settings pane), with custom fonts in particular.
5. In UI tests, `performAccessibilityAudit(for: [.dynamicType, .textClipped])` at Large and at AX5 ([testing.md](testing.md#audits)). *Measured:* `.system(size: 13)` was flagged "Dynamic Type font sizes are unsupported".
6. In Xcode previews, `.dynamicTypeSize(.accessibility5)` on the preview, and the canvas Display override for the other display ([Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)).
