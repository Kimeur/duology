# Bar rules on iPhone Duo

Depth for [`../SKILL.md`](../SKILL.md). Each rule names its source. *Measured* means we ran a probe app on the iPhone Duo simulator (Xcode 27.1, iOS 27.1) on 16 October 2026, inner display, fully open, held wide. We could not change poses from the command line, so the outer display, portrait, partially folded and Split View were not measured.

## Sources

| Tag | Page |
|---|---|
| HIG | [Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), sections Vertical controls, Split views, Arrangement views |
| Hub | [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo), sections Optimize bars for vertical presentation, Organize items in your bars |
| 111461 | [Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/) |
| 111462 | [Raise the bar with iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111462/) |
| 111463 | [Strike a pose with adaptive layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/) |
| 111466 | [Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/) |
| Prepare | [Three steps to make your app shine on iPhone Duo](https://developer.apple.com/iphone-duo/prepare/) |

Duology's full list, with IDs and check dates: [reference/sources.md](https://github.com/Kimeur/duology/blob/main/reference/sources.md).

## When bars go vertical

| Context | Result | Source |
|---|---|---|
| Built with the iOS 26 SDK or the iOS 27 SDK | No vertical bars; Apple shows the app beside the status bar instead | Prepare, 111461 |
| Built with the iOS 27.1 SDK or later | Vertical bars where the pose calls for them | Prepare, 111461 |
| Outer display, portrait or landscape | Vertical | HIG, 111462 |
| Inner display, landscape | Vertical | HIG, 111462; *measured* (trailing edge) |
| Inner display, portrait | Horizontal top and bottom bars | HIG, 111462, 111466 |
| Split View multitasking | Each app's bar on its outer edge; the left app's bar on the left | HIG, 111466 |
| Right-to-left languages | Same hardware edge; content flows around it | HIG, 111462 |
| Bars from a hand-built `UIToolbar`, `UINavigationBar` or `UITabBar` | Ignored for vertical layout | Hub, 111462 |
| Keyboard accessory bars | Stay attached to the keyboard | 111462 |

The vertical bar shares its strip with the Dynamic Island and the status bar. When space runs out, items move into the overflow menu (111466).

## What goes into the vertical bar

| Item | Vertical? | Source |
|---|---|---|
| Symbol, with or without a title | Yes, shown as the symbol | Hub |
| Title only | No, stays horizontal | Hub, 111462 |
| Custom view | No, unless `axisBehavior` is `.verticalPreferred` | Hub, 111462 |
| Item with `.horizontalOnly` | Never; hidden if no horizontal bar exists | [SwiftUI doc](https://developer.apple.com/documentation/swiftui/toolbaritemaxisbehavior/horizontalonly) |
| System `EditButton` | Stays horizontal on its own | 111462 |
| Items in the overflow menu | Shown with symbol and title | Hub |

*Measured:*

- A text-only item ("EditText") and a `.horizontalOnly` item stayed in a horizontal bar at the top, next to the title, while the other items went vertical.
- In UIKit, a symbol item placed in the same `UIBarButtonItemGroup` as a text-only item stayed horizontal with it. In SwiftUI we did not test a mixed group.

Inside the vertical bar:

- Top-bar items sit at the top, bottom-bar items at the bottom, and the tab bar at the foot. The system keeps a gap between the top and bottom sets (HIG, 111466).
- Items keep their groups. Flexible spacers have zero size on the vertical axis; fixed spacers keep their minimum size (111462).
- The vertical bar has no scroll-edge effect by default. With Reduce Transparency on it gets a background, so custom item views must stay legible on both (111462).
- *Measured* order with a `.cancellationAction` Close, a `.topBarPinnedTrailing` Done, a `ToolbarOverflowMenu` and a `.bottomBar` group: Close, Done, overflow button at the top; the group at the bottom.

## Which screen decides

`toolbarVerticalBehavior(_:)` is resolved per window, or per presentation inside a sheet. Containers pick one view to ask ([doc](https://developer.apple.com/documentation/swiftui/view/toolbarverticalbehavior(_:))):

| Container | Asks |
|---|---|
| `NavigationStack` | The top view of the stack |
| `TabView` | The selected tab |
| `NavigationSplitView` | The trailing-most column |
| Sheet | Its own content |

UIKit works the same way through `childForPreferredVerticalBarBehavior`: `UINavigationController` forwards to its top view controller and `UITabBarController` to its selected one ([doc](https://developer.apple.com/documentation/uikit/uiviewcontroller/childforpreferredverticalbarbehavior)). A custom container should forward too.

When the choice changes, the system animates: bars move between axes, the status bar turns, and the side inset appears or goes. *Measured (UIKit):* after `setNeedsUpdateOfVerticalBarConfiguration()` with `.disabled`, the trailing safe-area inset went to 0, the bottom toolbar came back, and `verticalBarEdge` changed to `.unspecified`.

## Overflow and compression

- Default overflow order: from the bottom of the bar upward (HIG, 111462).
- `ToolbarItemVisibilityPriority`: `.automatic`, `.low`, `.high`, and `init(lowerThan:)` / `init(higherThan:)` for values in between. A custom value never crosses the next system level ([doc](https://developer.apple.com/documentation/swiftui/toolbaritemvisibilitypriority/init(lowerthan:))).
- `UIBarButtonItemVisibilityPriority`: `.standard`, `.low`, `.high`, with the same two initializers. A group made implicitly from items takes their priority ([doc](https://developer.apple.com/documentation/uikit/uibarbuttonitem/visibilitypriority)).
- Rank in this order: frequent actions such as Compose or New Note; items that show status, such as badges; the rest (HIG).
- `topBarPinnedTrailing` items overflow only while search is active and space runs out ([doc](https://developer.apple.com/documentation/swiftui/toolbaritemplacement/topbarpinnedtrailing)). UIKit's `pinnedTrailingGroup` never overflows; give it a `representativeItem` when it holds more than one item ([doc](https://developer.apple.com/documentation/uikit/uinavigationitem/pinnedtrailinggroup)).
- `ToolbarOverflowMenu` content always sits in the overflow menu ([doc](https://developer.apple.com/documentation/swiftui/toolbaroverflowmenu)). Setting `additionalOverflowItems` in UIKit shows the overflow button even when the menu is otherwise empty ([doc](https://developer.apple.com/documentation/uikit/uinavigationitem/additionaloverflowitems)).
- Space runs short most on the outer display in landscape, and when the keyboard or Picture in Picture takes room (111462).

| Compression value | Keeps | Use for | Source |
|---|---|---|---|
| `.automatic` | The tab bar (on iOS) | Default | [doc](https://developer.apple.com/documentation/swiftui/toolbarverticalcompressionbehavior/automatic) |
| `.prefersTabBar` | The tab bar; toolbar items overflow first | Navigation screens, such as Podcasts | [doc](https://developer.apple.com/documentation/swiftui/toolbarverticalcompressionbehavior/preferstabbar), 111462 |
| `.prefersToolbarItems` (UIKit `.prefersBarItems`) | Toolbar items; the tab bar shrinks first | Task screens, such as Files or Games | [doc](https://developer.apple.com/documentation/swiftui/toolbarverticalcompressionbehavior/preferstoolbaritems), 111462 |

Talk 111462 calls the SwiftUI modifier "toolbarCompressionBehavior". The real name is `toolbarVerticalCompressionBehavior(_:)`.

## Split views and inspectors

- Closed: columns collapse into one stack. Open: columns show tiled or as overlays (111461).
- Partially folded: the system resizes columns into an even split around the fold (HIG, 111463).
- Only the column on the display edge joins the vertical bar: the detail column. Sidebar and content columns keep horizontal bars. An expanded inspector gets no vertical bar of its own (Hub, 111462).
- *Measured:* the detail column's toolbar went vertical on the trailing edge; the sidebar's toolbar stayed horizontal; the sidebar column reported a compact width class while the detail column reported regular.
- Controls that act on the list belong on the list column; controls for the open item belong on the detail column (HIG, Mail example).
- Arrangement views lay out content but don't navigate. Put them inside navigation containers. Don't put an arrangement inside a split view, list or scroll view (HIG, Hub, 111463).

## Tabs and the sidebar

- By default tabs show on both displays and go vertical where the pose calls for it. On the inner display you can opt into a sidebar (111461).
- Apple suggests a sidebar for information-dense apps, such as Health (111466).
- SwiftUI: `defaultTabBarPlacement(_:)` applies to `.sidebarAdaptable` tab views, on platforms where the bar can't switch between forms. It does nothing on iPad ([doc](https://developer.apple.com/documentation/swiftui/view/defaulttabbarplacement(_:))).
- UIKit: `sidebar.preferredPlacement` matters only where sidebar and tab bar can't both show. `.automatic` means a tab bar on iOS ([doc](https://developer.apple.com/documentation/uikit/uitabbarcontroller/sidebar-swift.class/preferredplacement)).
- *Measured (SwiftUI):* `.sidebarAdaptable` plus `.defaultTabBarPlacement(.sidebar)` showed a sidebar on the inner display. `isTabViewSidebarAvailable` was `true`. `tabBarPlacement` still read `bottomBar`.
- *Measured (UIKit):* with `mode` left at `.automatic` and no tab groups, `preferredPlacement = .sidebar` showed a vertical tab bar and `sidebar.isAvailable` was `false`. With `mode = .tabSidebar` the sidebar showed and `isAvailable` was `true`. Apple's header says `.automatic` resolves to `.tabSidebar` only when a tab is a group.
- Gate sidebar-only UI on `isTabViewSidebarAvailable` or `sidebar.isAvailable` ([doc](https://developer.apple.com/documentation/swiftui/environmentvalues/istabviewsidebaravailable)).

## Sheets and other presentations

| Where | Default | With a placement | Source |
|---|---|---|---|
| Outer display | Toolbar vertical | Turn it off in the sheet for a single Close item; the sheet then stops short of the front camera and the status bar moves | Hub, 111466 |
| Inner display | Centred, toolbar horizontal | `.leading`: horizontal. `.trailing`: vertical | Hub, 111462; *measured* |
| Partially folded | Slides off the fold | Not needed | 111466 |

- *Measured:* a `.medium` sheet with `.trailing` placement sat on the right with a vertical bar (Close at the top). With `.automatic` or `.leading` it had a horizontal bar, and `toolbarVerticalEdge` read `nil` inside it. Each sheet reported a compact width class.
- Talk 111462 describes the inner-display rule as left and right; the hub says leading and trailing. *Unverified:* which wins in right-to-left languages.
- `UISheetPresentationController.preferredPlacement` is ignored when `sourceView` is set (UIKit header `UISheetPresentationController.h`).
- Alerts, action sheets, menus and popovers reposition around the fold on their own. Partially folded and held like a book, alerts move to the trailing side, close to where they appear once the phone closes (111463).

## Margins and backgrounds

- Bars sit outside the safe area. Horizontal bars add top and bottom insets; vertical bars add leading or trailing insets (111461).
- Margins are asymmetric too: content can get closer to the vertical bar while the other side keeps its margin (111461). `ContentMarginGuide.container` gives these margins; Apple says they can differ per side next to a vertical bar ([doc](https://developer.apple.com/documentation/swiftui/contentmarginguide/container)).
- *Measured (SwiftUI and UIKit):* with a vertical bar on the trailing edge, the trailing content margin inside the safe area was 0 and the leading one was the usual system margin.
- Let hero art run under the bar with `backgroundExtensionEffect()` (SwiftUI) or `UIBackgroundExtensionView` (UIKit) (Hub).
- Layouts that don't scroll and need no bars, like Calculator, can span the full width if nothing hits the Dynamic Island or the status bar (HIG).

## Availability

| API | Since |
|---|---|
| `toolbarVerticalBehavior(_:)`, `toolbarVerticalEdge`, `toolbarVerticalCompressionBehavior(_:)`, `axisBehavior(_:)`, `contentMargins(for:edges:alignment:)` | iOS 27.1 |
| `preferredVerticalBarBehavior`, `childForPreferredVerticalBarBehavior`, `setNeedsUpdateOfVerticalBarConfiguration()`, `verticalBarEdge`, `systemTraitsAffectingVerticalBarEdge`, `verticalBarCompressionBehavior`, `UIBarButtonItem.axisBehavior` | iOS 27.1 |
| `visibilityPriority(_:)`, `topBarPinnedTrailing`, `ToolbarOverflowMenu`, `toolbarOverflowMenu(content:)`, `defaultTabBarPlacement(_:)`, `isTabViewSidebarAvailable`, `presentationPlacement(_:)` | iOS 27.0 |
| `UIBarButtonItem.visibilityPriority`, `UITabBarController.Sidebar.preferredPlacement`, `.isAvailable`, `sidebarAvailabilityDidChange`, `UISheetPresentationController.preferredPlacement` | iOS 27.0 |
| `backgroundExtensionEffect()`, `UIBackgroundExtensionView`, `ButtonRole.close`, `.confirm`, `UIBarButtonItem.badge` | iOS 26.0 |
| `.sidebarAdaptable`, `UITabBarController.mode`, `UITab` | iOS 18.0 |
| `pinnedTrailingGroup`, `additionalOverflowItems`, `leadingItemGroups` | iOS 16.0 |

All checked in the iOS 27.1 simulator SDK interfaces. Duology's full API table: [reference/api-index.md](https://github.com/Kimeur/duology/blob/main/reference/api-index.md).

## Re-check on the simulator

Drop this view into any screen to log the bar edge, safe area and margins. Change poses in Device Hub and read the console.

```swift
import SwiftUI

struct BarProbe: View {
    let tag: String
    @Environment(\.toolbarVerticalEdge) private var edge
    @Environment(\.horizontalSizeClass) private var widthClass

    var body: some View {
        GeometryReader { proxy in
            let inset = proxy.safeAreaInsets
            let margin = proxy.contentMargins(for: .container, edges: .horizontal)
            let line = "\(tag) edge=\(String(describing: edge)) width=\(String(describing: widthClass)) "
                + "safe(leading \(inset.leading), trailing \(inset.trailing), top \(inset.top), bottom \(inset.bottom)) "
                + "margins(leading \(margin.leading), trailing \(margin.trailing))"
            Text(line)
                .font(.caption)
                .onAppear { print("BARPROBE", line) }
                .onChange(of: line) { _, new in print("BARPROBE", new) }
        }
    }
}
```

## Still to check

- Every rule above on the outer display, in portrait on the inner display, partially folded and in Split View. We measured only the inner display, fully open, held wide.
- Whether the outer display keeps a tab bar when the app asks for a sidebar.
- Whether `.horizontalOnly` items hide on screens with no title and no horizontal bar.
- Mixed text and symbol groups in SwiftUI.
- Sheet placement in right-to-left languages.
- Everything on a real iPhone Duo.
