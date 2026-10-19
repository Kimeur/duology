# UIKit recipes for bars on iPhone Duo

UIKit code for [`../SKILL.md`](../SKILL.md). Every block typechecks on its own against the iOS 27.1 simulator SDK, in Swift 5 and Swift 6 mode. Rules and sources: [`bar-rules.md`](bar-rules.md).

## SwiftUI to UIKit

| Job | SwiftUI | UIKit |
|---|---|---|
| Opt out of the vertical bar | `toolbarVerticalBehavior(.disabled)` | override `preferredVerticalBarBehavior`, return `.disabled` |
| Tell the system the choice changed | automatic | `setNeedsUpdateOfVerticalBarConfiguration()` |
| Let a child decide | container rules | override `childForPreferredVerticalBarBehavior` |
| Read the bar edge | `@Environment(\.toolbarVerticalEdge)` (`HorizontalEdge?`) | `traitCollection.verticalBarEdge` (`.unspecified`, `.leading`, `.trailing`) |
| Hear edge changes | view updates | `registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge)` |
| Toolbar or tab bar first | `toolbarVerticalCompressionBehavior(_:)` | `navigationItem.verticalBarCompressionBehavior` |
| Axis of one item | `axisBehavior(_:)` | `UIBarButtonItem.axisBehavior` |
| Overflow order | `visibilityPriority(_:)` | `UIBarButtonItem.visibilityPriority` (`.standard`, `.low`, `.high`) |
| Custom Close | `ToolbarItem(placement: .cancellationAction)` | `navigationItem.leadingItemGroups`, `leftItemsSupplementBackButton = false` (default) |
| Prominent action | `.topBarPinnedTrailing` | `navigationItem.pinnedTrailingGroup` |
| Always-in-overflow actions | `ToolbarOverflowMenu` | `navigationItem.additionalOverflowItems` |
| Tabs to sidebar | `.tabViewStyle(.sidebarAdaptable)` + `.defaultTabBarPlacement(.sidebar)` | `mode = .tabSidebar` + `sidebar.preferredPlacement = .sidebar` |
| Sidebar there? | `isTabViewSidebarAvailable` | `sidebar.isAvailable` + `tabBarController(_:sidebarAvailabilityDidChange:)` |
| Sheet side | `presentationPlacement(_:)` | `sheetPresentationController.preferredPlacement` |
| Art under the bar | `backgroundExtensionEffect()` | `UIBackgroundExtensionView` |

## A view controller with well-ordered bars

```swift
import UIKit

final class NoteViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Note"

        // First in the vertical bar: Close. Leading items replace Back,
        // because leftItemsSupplementBackButton stays false.
        let close = UIBarButtonItem(title: "Close", image: UIImage(systemName: "xmark"),
                                    primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        navigationItem.leadingItemGroups = [UIBarButtonItemGroup(barButtonItems: [close], representativeItem: nil)]

        // Second: the prominent action. A pinned group never overflows.
        let done = UIBarButtonItem(title: "Done", image: UIImage(systemName: "checkmark"),
                                   primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        done.style = .prominent
        navigationItem.pinnedTrailingGroup = UIBarButtonItemGroup(barButtonItems: [done], representativeItem: nil)

        // Bottom items: symbol plus title, ranked for overflow.
        let checklist = UIBarButtonItem(title: "Checklist", image: UIImage(systemName: "checklist"),
                                        primaryAction: UIAction { _ in })
        checklist.visibilityPriority = .high
        let inbox = UIBarButtonItem(title: "Inbox", image: UIImage(systemName: "tray"),
                                    primaryAction: UIAction { _ in })
        inbox.badge = .count(7)
        inbox.visibilityPriority = UIBarButtonItemVisibilityPriority(higherThan: .standard)
        let delete = UIBarButtonItem(title: "Delete", image: UIImage(systemName: "trash"),
                                     primaryAction: UIAction { _ in })
        delete.visibilityPriority = .low
        // No spacers: the system spaces items, horizontal or vertical.
        toolbarItems = [checklist, inbox, delete]

        // Actions that always live in the system overflow menu.
        navigationItem.additionalOverflowItems = UIDeferredMenuElement.uncached { provide in
            provide([
                UIAction(title: "Duplicate", image: UIImage(systemName: "plus.square.on.square")) { _ in },
                UIAction(title: "Print", image: UIImage(systemName: "printer")) { _ in },
            ])
        }

        // A task screen: shrink the tab bar before these items.
        navigationItem.verticalBarCompressionBehavior = .prefersBarItems
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = false
    }
}
```

- Use `UIBarButtonItem(title:image:primaryAction:menu:)` so every item has both a title and an image.
- Keep text-only items, such as "Edit", in their own group. *Measured:* a symbol item in the same group as a text-only item stayed horizontal with it.
- Don't add `.fixedSpace()` or `.flexibleSpace()` items. Group related items instead ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls)); Apple asks apps not to add their own spacing on either axis ([Tech Talk 111462](https://developer.apple.com/videos/play/tech-talks/111462/)).

## Items with a special axis

```swift
import UIKit

final class LibraryViewController: UIViewController {
    private var isSelecting = false

    // A custom view that fits the bar's fixed width may go vertical.
    private lazy var compassItem: UIBarButtonItem = {
        let item = UIBarButtonItem(customView: UIImageView(image: UIImage(systemName: "location.north.circle")))
        item.title = "Compass"
        item.axisBehavior = .verticalPreferred
        return item
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Library"
        updateTrailingItems()
    }

    /// Both items sit on the trailing side. Leading items would replace Back
    /// (leftItemsSupplementBackButton is false by default) and take the top slot.
    private func updateTrailingItems() {
        // Swaps between a symbol and text, so it stays horizontal.
        let select: UIBarButtonItem
        if isSelecting {
            select = UIBarButtonItem(title: "Done", primaryAction: UIAction { [weak self] _ in self?.toggle() })
        } else {
            select = UIBarButtonItem(title: "Select", image: UIImage(systemName: "checkmark.circle"),
                                     primaryAction: UIAction { [weak self] _ in self?.toggle() })
        }
        select.axisBehavior = .horizontalOnly
        // trailingItemGroups replaces rightBarButtonItem(s), so set only this.
        navigationItem.trailingItemGroups = [
            UIBarButtonItemGroup(barButtonItems: [select], representativeItem: nil),
            UIBarButtonItemGroup(barButtonItems: [compassItem], representativeItem: nil),
        ]
    }

    private func toggle() {
        isSelecting.toggle()
        updateTrailingItems()
    }
}
```

The system edit item (`editButtonItem`) already stays horizontal ([Tech Talk 111462](https://developer.apple.com/videos/play/tech-talks/111462/)).

## Opting out

```swift
import UIKit

/// Full-screen video: horizontal bars for the whole screen, decided once.
final class PlayerViewController: UIViewController {
    override var preferredVerticalBarBehavior: UIVerticalBarBehavior { .disabled }
}

/// A sheet whose only item is Close.
final class TipsViewController: UIViewController {
    override var preferredVerticalBarBehavior: UIVerticalBarBehavior { .disabled }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
    }
}

/// A custom container forwards the choice to the child on screen.
final class PagerViewController: UIViewController {
    private(set) var current: UIViewController?

    override var childForPreferredVerticalBarBehavior: UIViewController? { current }

    func show(_ child: UIViewController) {
        current?.willMove(toParent: nil)
        current?.view.removeFromSuperview()
        current?.removeFromParent()

        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(child.view)
        child.didMove(toParent: self)
        current = child

        // The answer to childForPreferredVerticalBarBehavior changed.
        setNeedsUpdateOfVerticalBarConfiguration()
    }
}
```

- `preferredVerticalBarBehavior` is read-only. Override it; don't try to set it.
- Call `setNeedsUpdateOfVerticalBarConfiguration()` whenever the answer of either override changes. *Measured:* after the call, the vertical bar went away, the bottom toolbar came back, and `verticalBarEdge` read `.unspecified`.
- Apple asks you not to flip it from view state ([doc](https://developer.apple.com/documentation/uikit/uiviewcontroller/preferredverticalbarbehavior)). The container case above changes it only because a different screen is now on show.

## Reading the bar edge in custom UI

```swift
import UIKit

final class CanvasViewController: UIViewController {
    private let palette = UIView()
    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        palette.backgroundColor = .secondarySystemBackground
        palette.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(palette)

        let margins = view.layoutMarginsGuide
        // 16 pt clears the bar's items: the margin next to a vertical bar is 0 pt.
        leadingConstraint = palette.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: 16)
        trailingConstraint = palette.trailingAnchor.constraint(equalTo: margins.trailingAnchor, constant: -16)
        NSLayoutConstraint.activate([
            palette.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            palette.widthAnchor.constraint(equalToConstant: 200),
            palette.heightAnchor.constraint(equalToConstant: 44),
        ])
        placePalette()

        registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) { (self: Self, _: UITraitCollection) in
            self.placePalette()
        }
    }

    /// Keeps the palette on the vertical bar's side, near the thumb. No bar: trailing.
    private func placePalette() {
        let barOnLeading = traitCollection.verticalBarEdge == .leading
        let (on, off) = barOnLeading ? (leadingConstraint, trailingConstraint) : (trailingConstraint, leadingConstraint)
        off?.isActive = false  // turn the old side off first, so the two never conflict
        on?.isActive = true
    }
}
```

- Pin to `layoutMarginsGuide` or `safeAreaLayoutGuide`. Vertical bars add a side inset, and the margin next to the bar can be 0 ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)).
- The trait list can change while the edge stays the same, so the handler must be cheap and idempotent ([doc](https://developer.apple.com/documentation/uikit/uitraitcollection/systemtraitsaffectingverticalbaredge-475st)).

## Tabs to a sidebar on the inner display

```swift
import UIKit

final class RootTabsController: UITabBarController, UITabBarController.Sidebar.Delegate {
    init() {
        super.init(nibName: nil, bundle: nil)
        tabs = [
            UITab(title: "Summary", image: UIImage(systemName: "heart"), identifier: "summary") { _ in
                UINavigationController(rootViewController: UIViewController())
            },
            UITab(title: "Sharing", image: UIImage(systemName: "person.2"), identifier: "sharing") { _ in
                UINavigationController(rootViewController: UIViewController())
            },
        ]
        // Measured: with no tab groups, preferredPlacement alone showed no sidebar.
        mode = .tabSidebar
        sidebar.preferredPlacement = .sidebar
        sidebar.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func tabBarController(_ tabBarController: UITabBarController,
                          sidebarAvailabilityDidChange sidebar: UITabBarController.Sidebar) {
        // Show or hide sidebar-only UI here, for example landing pages for groups.
        print("Sidebar available:", sidebar.isAvailable)
    }
}
```

`mode = .automatic` turns into `.tabSidebar` only when one of the tabs is a group (`UITabBarController.h`). An app with tab groups may not need the `mode` line; set it anyway so the intent is clear.

## Split view controller

```swift
import UIKit

@MainActor
func makeNotesSplit() -> UISplitViewController {
    let list = UIViewController()
    list.title = "Notes"
    // Acts on the list: stays horizontal above the list column.
    list.navigationItem.rightBarButtonItem = UIBarButtonItem(
        title: "New Note", image: UIImage(systemName: "square.and.pencil"), primaryAction: UIAction { _ in })

    let detail = UIViewController()
    detail.title = "Note"
    // Acts on the open note: joins the vertical bar.
    detail.navigationItem.rightBarButtonItem = UIBarButtonItem(
        title: "Share", image: UIImage(systemName: "square.and.arrow.up"), primaryAction: UIAction { _ in })

    let split = UISplitViewController(style: .doubleColumn)
    split.setViewController(list, for: .primary)
    split.setViewController(detail, for: .secondary)
    return split
}
```

Closed, the split view collapses to one stack; partially folded, it evens out the columns around the fold. You write no code for either ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/), [Tech Talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/)).

## Sheets

```swift
import UIKit

extension UIViewController {
    /// Shows details on the trailing side of the inner display, so the content behind stays visible.
    func presentPlaceDetails(_ details: UIViewController) {
        let nav = UINavigationController(rootViewController: details)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.preferredPlacement = .trailing   // ignored when sheet.sourceView is set
        }
        present(nav, animated: true)
    }
}
```

- Leave `preferredPlacement` at `.automatic` unless the content behind matters. The sheet already slides off the fold when the phone is partially folded ([Tech Talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/)).
- On the inner display a trailing sheet gets a vertical bar; centred and leading sheets keep horizontal bars (*measured* in SwiftUI; [hub](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo#Optimize-bars-for-vertical-presentation)).

## Hero art under the bar

```swift
import UIKit

final class AlbumViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let art = UIImageView(image: UIImage(systemName: "music.note"))
        art.contentMode = .scaleAspectFill

        // Lays the art out in the safe area and fills the area under the bars with copies of its edges.
        let extensionView = UIBackgroundExtensionView()
        extensionView.contentView = art
        extensionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(extensionView)
        NSLayoutConstraint.activate([
            extensionView.topAnchor.constraint(equalTo: view.topAnchor),
            extensionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            extensionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            extensionView.heightAnchor.constraint(equalToConstant: 280),
        ])
    }
}
```

## Deployment targets below iOS 27.1

iPhone Duo always runs iOS 27.1 or later; the fallbacks run only on other iPhones. Mark overrides with `@available` and wrap property sets in `if #available`. This block typechecks with deployment targets iOS 15.0 to 26.0.

```swift
import UIKit

final class LegacyPlayerViewController: UIViewController {
    @available(iOS 27.1, *)
    override var preferredVerticalBarBehavior: UIVerticalBarBehavior { .disabled }

    override func viewDidLoad() {
        super.viewDidLoad()
        let share = UIBarButtonItem(title: "Share", image: UIImage(systemName: "square.and.arrow.up"),
                                    primaryAction: UIAction { _ in })
        if #available(iOS 27.0, *) {
            share.visibilityPriority = .high
        }
        if #available(iOS 27.1, *) {
            navigationItem.verticalBarCompressionBehavior = .prefersBarItems
        }
        navigationItem.rightBarButtonItem = share
    }
}
```
