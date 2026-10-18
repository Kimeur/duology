# UIKit continuity patterns

The UIKit rule is the same as in SwiftUI: keep the same objects, change their layout. A fold resizes the window ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)), so UIKit calls `viewWillTransition(to:with:)` and updates the traits of the view controllers you already have. Your hierarchy stays unless your code rebuilds it.

Every block typechecks against the iOS 27.1 simulator SDK in Swift 5 mode, Swift 6 mode, and Swift 6 with `MainActor` as the default isolation. Only the collection view pattern has run on the simulator (see [evidence.md](evidence.md)); the rest is typechecked only.

## Change layout in place on a trait change

Build both constraint sets once, then switch between them. The text view is never recreated, so its text, selection, first-responder state and undo history stay.

```swift
import UIKit

final class ArticleViewController: UIViewController {
    private let textView = UITextView()
    private let commentsView = UIView()
    private var compactConstraints: [NSLayoutConstraint] = []
    private var regularConstraints: [NSLayoutConstraint] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        for subview in [textView, commentsView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        let guide = view.safeAreaLayoutGuide
        compactConstraints = [      // stacked
            textView.topAnchor.constraint(equalTo: guide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            commentsView.topAnchor.constraint(equalTo: textView.bottomAnchor),
            commentsView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            commentsView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            commentsView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            commentsView.heightAnchor.constraint(equalTo: guide.heightAnchor, multiplier: 0.4),
        ]
        regularConstraints = [      // side by side
            textView.topAnchor.constraint(equalTo: guide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            commentsView.leadingAnchor.constraint(equalTo: textView.trailingAnchor),
            commentsView.topAnchor.constraint(equalTo: guide.topAnchor),
            commentsView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            commentsView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            commentsView.widthAnchor.constraint(equalTo: textView.widthAnchor),
        ]
        applyLayout()
        registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (self: Self, _: UITraitCollection) in
            self.applyLayout()
        }
    }

    private func applyLayout() {
        let compact = traitCollection.horizontalSizeClass == .compact
        NSLayoutConstraint.deactivate(compact ? regularConstraints : compactConstraints)
        NSLayoutConstraint.activate(compact ? compactConstraints : regularConstraints)
    }
}
```

- [registerForTraitChanges(_:handler:)](https://developer.apple.com/documentation/uikit/uitraitchangeobservable-67e94/registerfortraitchanges(_:handler:)) (iOS 17) runs the handler only for the traits you list. Naming `self: Self` in the closure avoids a retain cycle, per Apple's page. *Measured:* the handler ran on every `traitOverrides.horizontalSizeClass` change.
- You can also read `traitCollection.horizontalSizeClass` inside `layoutSubviews()` or `updateProperties()` (iOS 26); UIKit then tracks the trait for you ([Automatic trait tracking](https://developer.apple.com/documentation/uikit/automatic-trait-tracking)). `updateProperties()` also tracks `@Observable` models, so a UIKit screen can read the same model as a SwiftUI one ([Updating views automatically with observation tracking in UIKit](https://developer.apple.com/documentation/uikit/updating-views-automatically-with-observation-tracking-in-uikit)).
- Use `view.safeAreaLayoutGuide` or the layout margins. On Duo the two sides differ next to vertical bars (see `duo-layout`).
- If you must move a text view to another parent, save `selectedRanges` (iOS 26; `selectedRange` before that, which the SDK marks for deprecation) and `isFirstResponder` before the move, and restore them after.

## Collection views: columns from the width, anchor kept

A compositional layout that reads its environment changes columns on its own when the traits or size change. You never swap layouts or reload data. Remember the top item before the change and scroll back to it after the next layout pass.

```swift
import UIKit

final class FeedViewController: UICollectionViewController {
    private var dataSource: UICollectionViewDiffableDataSource<Int, Int>!
    private var pendingAnchor: IndexPath?

    init() {
        super.init(collectionViewLayout: Self.makeLayout())
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    static func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, environment in
            let compact = environment.traitCollection.horizontalSizeClass == .compact
            let columns = compact ? 2 : 4                       // even column counts
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1 / CGFloat(columns)),
                heightDimension: .absolute(120)))
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(120)),
                repeatingSubitem: item, count: columns)
            return NSCollectionLayoutSection(group: group)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let cell = UICollectionView.CellRegistration<UICollectionViewListCell, Int> { cell, _, number in
            var content = cell.defaultContentConfiguration()
            content.text = "Item \(number)"
            cell.contentConfiguration = content
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { view, path, number in
            view.dequeueConfiguredReusableCell(using: cell, for: path, item: number)
        }
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems(Array(1...200))
        dataSource.apply(snapshot)

        registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (self: Self, _: UITraitCollection) in
            self.rememberTopItem()                  // the column count is about to change
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        rememberTopItem()                           // the width is about to change
        super.viewWillTransition(to: size, with: coordinator)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let anchor = pendingAnchor else { return }
        pendingAnchor = nil
        collectionView.scrollToItem(at: anchor, at: .top, animated: false)
    }

    private func rememberTopItem() {
        // Keep the first anchor if a fold sends both a trait change and a size change.
        if pendingAnchor == nil { pendingAnchor = collectionView.indexPathsForVisibleItems.min() }
    }
}
```

- *Measured* (iOS 27.1 simulator, size class flipped with `traitOverrides`): with no restore, 4 → 2 columns put item 74 at the top instead of item 148. Scrolling inside the trait handler, even after `layoutIfNeeded()`, still ended at item 74. Scrolling in `viewDidLayoutSubviews()`, or on the next main-actor turn, kept item 148.
- [viewWillTransition(to:with:)](https://developer.apple.com/documentation/uikit/uicontentcontainer/viewwilltransition(to:with:)) runs before the size changes. Call `super` so children hear about it too. *Unverified:* this path on a real fold. The open simulator refused a rotation request from code, so we could not trigger a size transition.
- A custom layout can keep the anchor itself by overriding [targetContentOffset(forProposedContentOffset:)](https://developer.apple.com/documentation/uikit/uicollectionviewlayout/targetcontentoffset(forproposedcontentoffset:)), which the collection view calls during layout updates and transitions.
- Keep the selected item ID in your model as well as in the collection view. If you ever reload, select it again with `selectItem(at:animated:scrollPosition:)`.
- Never save `contentOffset` and put it back after a column change. The same offset shows different items.

## Split view: keep the detail when the phone closes

`UISplitViewController` collapses to one column on the outer display. Tell it to keep the detail on top when something is selected.

```swift
import UIKit

final class LibrarySplitController: UISplitViewController, UISplitViewControllerDelegate {
    var selectedID: Int?             // or read it from your model

    init() {
        super.init(style: .doubleColumn)
        delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func splitViewController(_ svc: UISplitViewController,
                             topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        selectedID == nil ? .primary : .secondary
    }
}
```

- Apple's page for [splitViewController(_:topColumnForCollapsingToProposedTopColumn:)](https://developer.apple.com/documentation/uikit/uisplitviewcontrollerdelegate/splitviewcontroller(_:topcolumnforcollapsingtoproposedtopcolumn:)) says UIKit calls it when the split view goes from regular to compact width, which is what closing the phone does.
- Set each column's view controller once. Don't build new ones in the delegate or on a trait change.

## Players

Keep one `AVPlayer` in a model and one `AVPlayerViewController` in a container that never goes away. Move the container's frame, not the player.

```swift
import UIKit
import AVKit

final class PlayerContainerViewController: UIViewController {
    let playerController = AVPlayerViewController()

    init(player: AVPlayer) {
        super.init(nibName: nil, bundle: nil)
        playerController.player = player            // the same player for the whole session
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(playerController)
        playerController.view.frame = view.bounds
        playerController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(playerController.view)
        playerController.didMove(toParent: self)
    }
}
```

- [AVPlayerViewController](https://developer.apple.com/documentation/avkit/avplayerviewcontroller) shows a player; it doesn't own playback. Don't pause in `viewWillDisappear(_:)` because a layout change hid the view.

## Restore after a relaunch

A fold doesn't need this. A relaunch does. Return an activity from [stateRestorationActivity(for:)](https://developer.apple.com/documentation/uikit/uiscenedelegate/staterestorationactivity(for:)) and read it back from the session when the scene connects ([Restoring your app's state](https://developer.apple.com/documentation/uikit/restoring-your-app-s-state)).

```swift
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let split = LibrarySplitController()
    static let browsingType = "com.example.library.browsing"   // also list it under NSUserActivityTypes

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        if let activity = session.stateRestorationActivity,
           let id = activity.userInfo?["selection"] as? Int {
            split.selectedID = id
        }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = split
        window.makeKeyAndVisible()
        self.window = window
    }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        let activity = NSUserActivity(activityType: Self.browsingType)
        if let id = split.selectedID { activity.userInfo = ["selection": id] }
        return activity
    }
}
```

- `LibrarySplitController` is the split view from the section above.
- Declare each activity type in the app's Info.plist, as Apple's [SwiftUI restoration sample](https://developer.apple.com/documentation/swiftui/restoring-your-app-s-state-with-swiftui) notes.
- Never set `window.rootViewController` again on a trait change. That throws away every screen in the window.
