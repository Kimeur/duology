# VoiceOver order across panes

How VoiceOver walks a two-pane screen on iPhone Duo, and how to make it read one pane at a time. Measurements are in [evidence.md](evidence.md).

## Why panes interleave

VoiceOver builds one linear path through the screen. It follows the reading order of the language: top to bottom, then leading to trailing in English ([HIG, VoiceOver](https://developer.apple.com/design/human-interface-guidelines/voiceover#Navigation)). It sorts by position, not by your view tree. Two columns whose rows line up are read as one table, row by row.

*Measured* on the iPhone Duo simulator, closed and open:

| Layout | VoiceOver order |
|---|---|
| `HStack` of two plain panes | `Inbox, Message, Left 1, Right 1, Left 2, Right 2, …` |
| Right pane 20 pt lower | Same interleaving |
| `ArrangementView` (`.split.axes(.horizontal)`), open | Same interleaving |
| `NavigationSplitView`, open | `Hide Sidebar, Sidebar, Left 1, Left 2, Left 3, Message, Right 1, …` |
| Each pane `accessibilityElement(children: .contain)` with a label | `Inbox, Left 1, Left 2, Left 3, Message pane, Message, Right 1, …` |
| Same, right pane `accessibilitySortPriority(1)` | `Message, Right 1, Right 2, Right 3, Inbox pane, Inbox, Left 1, …` |

Closed, the arrangement and the split view showed only their first pane, so there was nothing to interleave.

## The fix: one container per pane

`accessibilityElement(children: .contain)` turns a view into a container. VoiceOver reads every child of one container before it moves to the next ([doc](https://developer.apple.com/documentation/swiftui/accessibilitychildbehavior/contain)). Give the container a label: VoiceOver says it when it enters the pane.

```swift
import SwiftUI

extension View {
    /// One VoiceOver container per pane. A higher priority is read first.
    func accessibilityPane(_ label: LocalizedStringKey, priority: Double = 0) -> some View {
        accessibilityElement(children: .contain)
            .accessibilityLabel(label)
            .accessibilitySortPriority(priority)
    }
}
```

Don't use `.combine` on a pane. It merges the children into one element, so VoiceOver reads the whole pane as one long label and people can't move to the items inside it ([doc](https://developer.apple.com/documentation/swiftui/view/accessibilityelement(children:))). Keep `.combine` for small groups such as one list row.

## Recipes by pattern

The pattern names come from `duo-patterns`.

| Pattern | What to do |
|---|---|
| List-detail with `NavigationSplitView` | Nothing for order: the system groups the columns. Add the header trait to the detail title. |
| Supporting pane, dual view (`ArrangementView` split) | `accessibilityPane` on the primary and on the secondary. |
| Your own split (`HStack`, `EvenSplit`, `FoldSplitLayout`) | `accessibilityPane` on each half. |
| Two-page | Each page is a pane labelled "Page 12 of 40". Keep the page header as a heading. |
| Overlay arrangement (controls over content) | Content and controls as two panes. Decide which comes first and set the priority once. The default order follows position, so bottom controls come last (*unverified* for the overlay style). |
| Two people on one screen | One pane per person, the first seat with the higher priority. See `duo-shared-screen`. |

```swift
import SwiftUI

// Uses accessibilityPane from the section above.
struct TwoPageSpread: View {
    let left: Int
    let total: Int

    var body: some View {
        HStack(spacing: 40) {          // the gap sits on the fold
            page(left)
            page(left + 1)
        }
    }

    private func page(_ number: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chapter \(number)").font(.headline).accessibilityAddTraits(.isHeader)
            Text("Page text")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityPane("Page \(number) of \(total)")
    }
}
```

## Sort priority rules

- Priority sorts siblings at the same level. Put it on the pane containers, not on rows inside them. Higher numbers go first; the default is 0 ([doc](https://developer.apple.com/documentation/swiftui/view/accessibilitysortpriority(_:))).
- Set it once per screen. Never switch it by pose, size class or hinge state: people learn where things are.
- Use it only when the leading pane is not the one people want first, for example a player whose controls sit on the leading side.
- Right-to-left languages: VoiceOver follows the reading direction, so the leading pane (on the right) comes first without a priority (*unverified*: we measured left to right only).

## Headings and the rotor

Mark each pane's title with `.accessibilityAddTraits(.isHeader)`. VoiceOver users can then flick by heading with the rotor and jump from one pane to the other ([HIG, VoiceOver](https://developer.apple.com/design/human-interface-guidelines/voiceover#Navigation)). For long lists, a custom rotor lists the items people jump between:

```swift
import SwiftUI

struct Mail: Identifiable { let id: Int; let subject: String; let isUnread: Bool }

struct InboxList: View {
    let mails: [Mail]

    var body: some View {
        List(mails) { mail in
            Text(mail.subject).id(mail.id)
        }
        .accessibilityRotor("Unread") {
            ForEach(mails.filter(\.isUnread)) { mail in
                AccessibilityRotorEntry(mail.subject, id: mail.id)
            }
        }
    }
}
```

## UIKit

Group each pane's view, and give the container an explicit order:

```swift
import UIKit

final class TwoPaneView: UIView {
    let listPane = UIView()
    let detailPane = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        for (pane, name) in [(listPane, "Messages"), (detailPane, "Message")] {
            addSubview(pane)
            pane.shouldGroupAccessibilityChildren = true   // read this pane's children together
            pane.accessibilityContainerType = .semanticGroup
            pane.accessibilityLabel = name                 // spoken when VoiceOver enters the pane
        }
        accessibilityElements = [listPane, detailPane]     // the order between panes
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
```

- `shouldGroupAccessibilityChildren` asks VoiceOver to keep a view's children together ([doc](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/shouldgroupaccessibilitychildren)).
- With `UIArrangementViewController`, set these on each child view controller's view.
- `UISplitViewController` groups its columns like `NavigationSplitView` (*unverified*: we measured the SwiftUI split view only).

## Check it

- Accessibility Inspector: select the first element, press the navigation play button and listen. One pane should finish before the next starts.
- UI test: walk with `XCUIDevice.shared.voiceOverService` and assert the order ([testing.md](testing.md#a-voiceover-walk)). Don't use the order of `app.staticTexts`: on the split view it differed from VoiceOver's order (*measured*).
