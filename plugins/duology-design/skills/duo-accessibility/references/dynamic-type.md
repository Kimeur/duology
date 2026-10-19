# Dynamic Type on both displays

The text size is one setting for the whole phone. The room for text is not: inside the safe area, the closed outer display is 382 pt wide and the open inner display 867 pt, held wide with the vertical bar on the right (both *measured* by `duo-design-system`; the open window is 951 pt, and the bar's column takes the rest). A layout that reads well open can clip closed at the same size. Apple wants text enlargeable by at least 200 percent, as much text visible at the largest accessibility size as at the largest standard size, and stacked layouts when inline items crowd the text ([HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Vision), [HIG, Typography](https://developer.apple.com/design/human-interface-guidelines/typography#Supporting-Dynamic-Type)).

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
            strip.labelStyle(.titleAndIcon)
            strip.labelStyle(.iconOnly)                 // titles stay for VoiceOver and Voice Control
        }
    }

    private var strip: some View {
        HStack(spacing: 16) {
            button("Play", "play.fill", play)
            button("Skip 15 Seconds", "goforward.15", skip)
        }
    }

    private func button(_ title: LocalizedStringKey, _ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(minWidth: 44, minHeight: 44)     // 44 pt hit area, inside the label (duo-ergonomics)
                .contentShape(.rect)
        }
    }
}
```

The frame and `contentShape` sit inside the label. *Measured* by the audit: a plain icon button was 16 × 16 pt, and a 44 pt frame outside the label still gave "Hit area is too small" ([testing.md](testing.md#audits)).

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

- The two halves of the open display differ. Inside the 867 pt safe area, a split at the fold's 40 pt frame (x 455.5 to 495.5, *measured* by `duo-layout`) leaves about 455 pt for the pane away from the vertical bar and about 371 pt for the pane beside it (*derived*). Flat, with a 16 pt gutter on the fold line instead (`duo-design-system`), the pane beside the bar gets about 383 pt.
- So the pane beside the bar is about as narrow as the closed display (382 pt), or narrower, before margins. Don't assume a pane that works closed fits there: check it at AX5 on its own, flat and partly folded.
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
