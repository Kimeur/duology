# API index

Every iPhone Duo API that Duology skills use, checked against the iOS 27.1 SDK. From v0.2 it also lists the standard SwiftUI, UIKit, XCUIAutomation and macOS APIs that the design, accessibility, scenes and pose skills rely on, from [Liquid Glass and corners](#liquid-glass-and-corners) down. Those aren't Duo-specific; they are here so every name in a skill can be checked.

- **Checked with:** Xcode 27.1 (27A9275), iOS 27.1 simulator SDK (build 24A94232), on 16 October 2026. The v0.2 sections were checked on 19 October 2026: each declaration against the SDK interfaces (XCUIAutomation in the iPhone Simulator platform, the macOS Accessibility API in the macOS SDK), each doc link through Apple's documentation JSON, and the SwiftUI and UIKit spellings in one scratch file that typechecks with no errors or warnings at an iOS 27.1 target.
- **Where we looked:** the SwiftUI and SwiftUICore `.swiftinterface` files, the UIKit headers and `UIKit.swiftinterface`, the AVFoundation headers and the AVKit headers inside that SDK. Each doc link was fetched from Apple's documentation JSON and returned a page.
- **Declarations** come from the SDK. To keep rows short we removed module prefixes (`SwiftUICore::`, `Swift.`), access and isolation keywords (`public`, `open`, `nonisolated`, `@MainActor @preconcurrency` on members) and doc comments. UIKit, AVFoundation and AVKit rows show the Swift form, read from Apple's doc JSON and from `swift-synthesize-interface` output for the SDK.
- **Availability** is the iOS version in the SDK's `@available` or `API_AVAILABLE` attribute. In SwiftUI, `anyAppleOS 27.1` means every Apple platform at version 27.1.
- **Proof of spelling:** [`api-smoke.swift`](api-smoke.swift) uses the key SwiftUI APIs and typechecks with no errors or warnings, in Swift 5 and Swift 6 mode, with deployment targets iOS 27.1 and iOS 26.0. We also typechecked every UIKit, AVFoundation and AVKit spelling in this file, in scratch files that are not part of the repo.

```bash
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer \
xcrun -sdk iphonesimulator swiftc -typecheck \
  -target arm64-apple-ios27.1-simulator reference/api-smoke.swift
```

Apple's overview of all of this: [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo).

## Build behaviour, screens and corners

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `UIWindowScene.screen` | UIKit | `var screen: UIScreen { get }` | iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uiwindowscene/screen) |
| `UITraitCollection.displayScale` | UIKit | `var displayScale: CGFloat { get }` | iOS 8.0 | [doc](https://developer.apple.com/documentation/uikit/uitraitcollection/displayscale) |
| `UIWindowSceneDelegate.supportedInterfaceOrientations(for:)` | UIKit | `optional func supportedInterfaceOrientations(for windowScene: UIWindowScene) -> UIInterfaceOrientationMask` | iOS 27.0 | [doc](https://developer.apple.com/documentation/uikit/uiwindowscenedelegate/supportedinterfaceorientations(for:)) |
| `UIRequiresFullScreen` | Info.plist key | Boolean | iOS 9.0, deprecated in iOS 26.0 (doc) | [doc](https://developer.apple.com/documentation/bundleresources/information-property-list/uirequiresfullscreen) |
| `ConcentricRectangle` | SwiftUI | `struct ConcentricRectangle : Shape, Animatable` with `init(corners: Edge.Corner.Style, isUniform: Bool = false)` | iOS 26.0 | [doc](https://developer.apple.com/documentation/swiftui/concentricrectangle) |
| `GeometryProxy.concentricCornerRadii` | SwiftUI | `var concentricCornerRadii: RectangleCornerRadii? { get }` | iOS 27.0 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/geometryproxy/concentriccornerradii) |
| `UICornerConfiguration` | UIKit | `struct UICornerConfiguration : Equatable, Hashable, CustomStringConvertible` | iOS 26.0 | [doc](https://developer.apple.com/documentation/uikit/uicornerconfiguration-swift.struct) |
| `UIView.cornerConfiguration` | UIKit | `var cornerConfiguration: UICornerConfiguration { get set }` | iOS 26.0 | [doc](https://developer.apple.com/documentation/uikit/uiview/cornerconfiguration-7l0ja) |

- The scene delegate method lets a scene return its own orientation mask instead of the Info.plist value.
- Apple deprecated `UIRequiresFullScreen` in iOS 26. See [TN3192](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key) for what to use instead.

## Anti-patterns for `duo-lint`

These exist in the SDK, but Apple tells you not to base layout on them. `duo-lint` is meant to flag them.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `UIScreen.main` | UIKit | `class var main: UIScreen { get }` | iOS 2.0, **deprecated in iOS 26.0** | [doc](https://developer.apple.com/documentation/uikit/uiscreen/main) |
| `UIDevice.orientation` | UIKit | `var orientation: UIDeviceOrientation { get }` | iOS 2.0, not deprecated | [doc](https://developer.apple.com/documentation/uikit/uidevice/orientation) |
| `UIApplication.statusBarOrientation` | UIKit | `var statusBarOrientation: UIInterfaceOrientation { get }` | iOS 2.0, deprecated in iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uiapplication/statusbarorientation) |
| `UIViewController.interfaceOrientation` | UIKit | `var interfaceOrientation: UIInterfaceOrientation { get }` | iOS 2.0, deprecated in iOS 8.0 | [doc](https://developer.apple.com/documentation/uikit/uiviewcontroller/interfaceorientation) |
| `UIWindowScene.interfaceOrientation` | UIKit | `var interfaceOrientation: UIInterfaceOrientation { get }` | iOS 13.0, deprecated in iOS 26.0 | [doc](https://developer.apple.com/documentation/uikit/uiwindowscene/interfaceorientation) |
| `UIDevice.userInterfaceIdiom` | UIKit | `var userInterfaceIdiom: UIUserInterfaceIdiom { get }` | iOS 3.2, not deprecated | [doc](https://developer.apple.com/documentation/uikit/uidevice/userinterfaceidiom) |

- The `UIScreen.main` deprecation message points to the screen of the view's window scene, or to a trait such as `displayScale`.
- The `UIWindowScene.interfaceOrientation` deprecation message points to `effectiveGeometry.interfaceOrientation`.
- Apple's Duo overview says to use size classes, not `userInterfaceIdiom` or the interface orientation, for layout decisions.

## Navigation and bars: SwiftUI

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `View.toolbarVerticalBehavior(_:)` | SwiftUI | `func toolbarVerticalBehavior(_ behavior: ToolbarVerticalBehavior) -> some View` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/view/toolbarverticalbehavior(_:)) |
| `ToolbarVerticalBehavior` | SwiftUI | `struct ToolbarVerticalBehavior : Hashable, Sendable` with `static let automatic`, `static let disabled` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/toolbarverticalbehavior) |
| `EnvironmentValues.toolbarVerticalEdge` | SwiftUI | `var toolbarVerticalEdge: HorizontalEdge? { get }` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/environmentvalues/toolbarverticaledge) |
| `View.toolbarVerticalCompressionBehavior(_:)` | SwiftUI | `func toolbarVerticalCompressionBehavior(_ behavior: ToolbarVerticalCompressionBehavior) -> some View` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/view/toolbarverticalcompressionbehavior(_:)) |
| `ToolbarVerticalCompressionBehavior` | SwiftUI | `struct ToolbarVerticalCompressionBehavior : Hashable, Sendable` with `automatic`, `prefersToolbarItems`, `prefersTabBar` | iOS 27.1; the two `prefers` values are iOS only | [doc](https://developer.apple.com/documentation/swiftui/toolbarverticalcompressionbehavior) |
| `ToolbarContent.axisBehavior(_:)` | SwiftUI | `func axisBehavior(_ behavior: ToolbarItemAxisBehavior) -> some ToolbarContent` (also on `CustomizableToolbarContent`) | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/toolbarcontent/axisbehavior(_:)) |
| `ToolbarItemAxisBehavior` | SwiftUI | `struct ToolbarItemAxisBehavior : Hashable, Sendable` with `automatic`, `horizontalOnly`, `verticalPreferred` | iOS 27.1; `horizontalOnly` and `verticalPreferred` unavailable on macOS, watchOS, tvOS, visionOS | [doc](https://developer.apple.com/documentation/swiftui/toolbaritemaxisbehavior) |
| `ToolbarContent.visibilityPriority(_:)` | SwiftUI | `func visibilityPriority(_ priority: ToolbarItemVisibilityPriority) -> some ToolbarContent` (also on `CustomizableToolbarContent`) | iOS 27.0, macOS 26.1 | [doc](https://developer.apple.com/documentation/swiftui/toolbarcontent/visibilitypriority(_:)) |
| `ToolbarItemVisibilityPriority` | SwiftUI | `struct ToolbarItemVisibilityPriority : Hashable, Sendable, Comparable` with `automatic`, `low`, `high`, `init(lowerThan:)`, `init(higherThan:)` | iOS 27.0, macOS 26.1 | [doc](https://developer.apple.com/documentation/swiftui/toolbaritemvisibilitypriority) |
| `ToolbarItemPlacement.topBarPinnedTrailing` | SwiftUI | `static let topBarPinnedTrailing: ToolbarItemPlacement` | iOS 27.0, visionOS 27.0 | [doc](https://developer.apple.com/documentation/swiftui/toolbaritemplacement/topbarpinnedtrailing) |
| `ToolbarOverflowMenu` | SwiftUI | `struct ToolbarOverflowMenu<Content> : ToolbarContent, CustomizableToolbarContent where Content : View` with `init(@ContentBuilder content: () -> Content)` | iOS 27.0, visionOS 27.0 | [doc](https://developer.apple.com/documentation/swiftui/toolbaroverflowmenu) |
| `View.toolbarOverflowMenu(content:)` | SwiftUI | `func toolbarOverflowMenu<C>(@ContentBuilder content: () -> C) -> some View where C : View` | iOS 27.0, visionOS 27.0 | [doc](https://developer.apple.com/documentation/swiftui/view/toolbaroverflowmenu(content:)) |
| `View.defaultTabBarPlacement(_:)` | SwiftUI | `func defaultTabBarPlacement(_ defaultPlacement: AdaptableTabBarPlacement) -> some View` | iOS 27.0 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/view/defaulttabbarplacement(_:)) |
| `AdaptableTabBarPlacement` | SwiftUI | `struct AdaptableTabBarPlacement : Hashable` with `automatic`, `tabBar`, `sidebar` | iOS 18.0 | [doc](https://developer.apple.com/documentation/swiftui/adaptabletabbarplacement) |
| `EnvironmentValues.isTabViewSidebarAvailable` | SwiftUI | `var isTabViewSidebarAvailable: Bool { get }` | iOS 27.0 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/environmentvalues/istabviewsidebaravailable) |
| `EnvironmentValues.tabBarPlacement` | SwiftUI | `var tabBarPlacement: TabBarPlacement? { get }` | iOS 18.0 | [doc](https://developer.apple.com/documentation/swiftui/environmentvalues/tabbarplacement) |
| `View.presentationPlacement(_:)` | SwiftUI | `func presentationPlacement(_ placement: PresentationPlacement) -> some View` | iOS 27.0 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/view/presentationplacement(_:)) |
| `PresentationPlacement` | SwiftUI | `struct PresentationPlacement : Hashable, Sendable` with `automatic`, `leading`, `center`, `trailing` | iOS 27.0; `leading`, `center`, `trailing` iOS only | [doc](https://developer.apple.com/documentation/swiftui/presentationplacement) |
| `View.backgroundExtensionEffect()` | SwiftUI | `func backgroundExtensionEffect() -> some View` | iOS 26.0 | [doc](https://developer.apple.com/documentation/swiftui/view/backgroundextensioneffect()) |

- `defaultTabBarPlacement(_:)` only acts on a `TabView` with `.tabViewStyle(.sidebarAdaptable)`. Apple's doc says it has no effect on iPad, where the bar can switch between forms.
- Apple's doc asks you to treat `.disabled` as a stable choice per screen, for example a full-screen video player. Don't toggle it from view state.
- `presentationPlacement(_:)` only affects sheets.
- `topBarPinnedTrailing` items move to the overflow menu only when search is active and space runs out.

## Navigation and bars: UIKit

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `UIViewController.preferredVerticalBarBehavior` | UIKit | `var preferredVerticalBarBehavior: UIVerticalBarBehavior { get }` | iOS 27.1, tvOS 27.1, visionOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiviewcontroller/preferredverticalbarbehavior) |
| `UIVerticalBarBehavior` | UIKit | `enum UIVerticalBarBehavior : Int` with `.automatic`, `.disabled` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiverticalbarbehavior) |
| `UIViewController.childForPreferredVerticalBarBehavior` | UIKit | `var childForPreferredVerticalBarBehavior: UIViewController? { get }` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiviewcontroller/childforpreferredverticalbarbehavior) |
| `UIViewController.setNeedsUpdateOfVerticalBarConfiguration()` | UIKit | `func setNeedsUpdateOfVerticalBarConfiguration()` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiviewcontroller/setneedsupdateofverticalbarconfiguration()) |
| `UITraitCollection.verticalBarEdge` | UIKit | `var verticalBarEdge: UIVerticalBarEdge { get }` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uitraitcollection/verticalbaredge) |
| `UIVerticalBarEdge` | UIKit | `enum UIVerticalBarEdge : Int` with `.unspecified`, `.leading`, `.trailing` | iOS 27.1; `.leading` and `.trailing` iOS only | [doc](https://developer.apple.com/documentation/uikit/uiverticalbaredge) |
| `UITraitCollection.systemTraitsAffectingVerticalBarEdge` | UIKit | `static var systemTraitsAffectingVerticalBarEdge: [UITrait] { get }` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uitraitcollection/systemtraitsaffectingverticalbaredge-475st) |
| `UINavigationItem.verticalBarCompressionBehavior` | UIKit | `var verticalBarCompressionBehavior: UIVerticalBarCompressionBehavior { get set }` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uinavigationitem/verticalbarcompressionbehavior) |
| `UIVerticalBarCompressionBehavior` | UIKit | `enum UIVerticalBarCompressionBehavior : Int` with `.automatic`, `.prefersBarItems`, `.prefersTabBar` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiverticalbarcompressionbehavior) |
| `UIBarButtonItem.axisBehavior` | UIKit | `var axisBehavior: UIBarButtonItem.AxisBehavior { get set }` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uibarbuttonitem/axisbehavior-swift.property) |
| `UIBarButtonItem.AxisBehavior` | UIKit | `enum AxisBehavior : Int` with `.automatic`, `.horizontalOnly`, `.verticalPreferred` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uibarbuttonitem/axisbehavior-swift.enum) |
| `UIBarButtonItem.visibilityPriority` | UIKit | `var visibilityPriority: UIBarButtonItemVisibilityPriority { get set }`; the struct has `.standard`, `.low`, `.high`, `init(lowerThan:)`, `init(higherThan:)` | iOS 27.0; `.low` and `.high` iOS only | [doc](https://developer.apple.com/documentation/uikit/uibarbuttonitem/visibilitypriority) |
| `UIView.LayoutRegion.bar(onEdge:extent:)` | UIKit | `static func bar(onEdge edge: NSDirectionalRectEdge, extent: CGFloat) -> UIView.LayoutRegion` (also a `UIRectEdge` overload) | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiview/layoutregion/bar(onedge:extent:)-2tj1g) |
| `UITabBarController.Sidebar.preferredPlacement` | UIKit | `var preferredPlacement: UITabBarController.Sidebar.Placement { get set }` | iOS 27.0, visionOS 27.0 | [doc](https://developer.apple.com/documentation/uikit/uitabbarcontroller/sidebar-swift.class/preferredplacement) |
| `UITabBarController.Sidebar.Placement` | UIKit | `enum Placement : Int` with `.automatic`, `.sidebar`, `.tabBar` | iOS 27.0 | [doc](https://developer.apple.com/documentation/uikit/uitabbarcontroller/sidebar-swift.class/placement) |
| `UITabBarController.Sidebar.isAvailable` | UIKit | `var isAvailable: Bool { get }` | iOS 27.0 | [doc](https://developer.apple.com/documentation/uikit/uitabbarcontroller/sidebar-swift.class/isavailable) |
| `UITabBarController.Sidebar.Delegate.tabBarController(_:sidebarAvailabilityDidChange:)` | UIKit | `optional func tabBarController(_ tabBarController: UITabBarController, sidebarAvailabilityDidChange sidebar: UITabBarController.Sidebar)` | iOS 27.0 | [doc](https://developer.apple.com/documentation/uikit/uitabbarcontroller/sidebar-swift.class/delegate-swift.protocol/tabbarcontroller(_:sidebaravailabilitydidchange:)) |
| `UISheetPresentationController.preferredPlacement` | UIKit | `var preferredPlacement: UISheetPresentationController.Placement { get set }` | iOS 27.0 | [doc](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller/preferredplacement) |
| `UISheetPresentationController.Placement` | UIKit | `enum Placement : Int` with `.automatic`, `.leading`, `.center`, `.trailing` | iOS 27.0 | [doc](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller/placement) |
| `UINavigationItem.pinnedTrailingGroup` | UIKit | `var pinnedTrailingGroup: UIBarButtonItemGroup? { get set }` | iOS 16.0 | [doc](https://developer.apple.com/documentation/uikit/uinavigationitem/pinnedtrailinggroup) |
| `UINavigationItem.additionalOverflowItems` | UIKit | `var additionalOverflowItems: UIDeferredMenuElement? { get set }` | iOS 16.0 | [doc](https://developer.apple.com/documentation/uikit/uinavigationitem/additionaloverflowitems) |
| `UIBackgroundExtensionView` | UIKit | `class UIBackgroundExtensionView : UIView` with `var contentView: UIView?` | iOS 26.0 | [doc](https://developer.apple.com/documentation/uikit/uibackgroundextensionview) |

- `preferredVerticalBarBehavior` is read-only. Override it, then call `setNeedsUpdateOfVerticalBarConfiguration()` when the answer changes.
- Navigation and tab bar controllers forward the vertical bar choice to their visible child by default.
- `UISheetPresentationController.preferredPlacement` is ignored when `sourceView` is set.
- Pass `systemTraitsAffectingVerticalBarEdge` to `registerForTraitChanges(_:handler:)` to hear when the bar edge may change.

## Reserved regions and margins

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `ReservedRegion` | SwiftUI | `struct ReservedRegion : Equatable, Hashable, Identifiable, Sendable` with `id`, `kind`, `frame: CGRect`, `margins: EdgeInsets`, `isActive: Bool` (all `get`) | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/reservedregion) |
| `ReservedRegion.Kind` | SwiftUI | `struct Kind : Hashable, Sendable` with `static var division`, `static var occlusion` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/reservedregion/kind-swift.struct) |
| `ReservedRegion.QueryOptions` | SwiftUI | `struct QueryOptions : OptionSet` with `static var includeInactive` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/reservedregion/queryoptions) |
| `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)` | SwiftUI | `func reservedRegions(kind: ReservedRegion.Kind, options: ReservedRegion.QueryOptions = [], layoutDirectionBehavior: LayoutDirectionBehavior = .mirrors) -> [ReservedRegion]` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:)) |
| `ContentMarginGuide` | SwiftUI | `struct ContentMarginGuide` with `static var container: ContentMarginGuide { get }` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/contentmarginguide) |
| `View.contentMargins(for:edges:alignment:)` | SwiftUI | `func contentMargins(for guide: ContentMarginGuide, edges: Edge.Set = .all, alignment: Alignment? = nil) -> some View` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/view/contentmargins(for:edges:alignment:)) |
| `GeometryProxy.contentMargins(for:edges:)` | SwiftUI | `func contentMargins(for guide: ContentMarginGuide, edges: Edge.Set = .all) -> EdgeInsets` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/geometryproxy/contentmargins(for:edges:)) |
| `UIView.ReservedRegion` | UIKit | `struct ReservedRegion : Equatable, Hashable, Identifiable` with `let id`, `let kind`, `let frame: CGRect`, `let margins: UIEdgeInsets`, `let isActive: Bool` | iOS 27.1, tvOS 27.1, visionOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiview/reservedregion) |
| `UIView.ReservedRegion.Kind` | UIKit | `struct Kind : Equatable, Hashable` with `static let occlusion`, `static let division` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiview/reservedregion/kind-swift.struct) |
| `UIView.ReservedRegion.QueryOptions` | UIKit | `struct QueryOptions : OptionSet` with `static let includeInactive` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiview/reservedregion/queryoptions) |
| `UIView.reservedRegions(kind:options:)` | UIKit | `func reservedRegions(kind: UIView.ReservedRegion.Kind, options: UIView.ReservedRegion.QueryOptions = []) -> [UIView.ReservedRegion]` | iOS 27.1, tvOS 27.1, visionOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiview/reservedregions(kind:options:)) |

- A **division** is the fold. Apple's overview says it is active when the phone is partly open and inactive when it is fully open.
- An **occlusion** is hardware that covers content. Apple's overview says the inner front camera occludes the view while it is active, and the outer front camera always occludes it.
- `frame` includes the `margins`, which add room for interactive content around the reserved area.
- SwiftUI mirrors region frames for right-to-left layouts by default. Pass `layoutDirectionBehavior: .fixed` to get unmirrored frames.
- Apple's `ReservedRegion` page says the query returns regions whether or not they are active, yet the API has an `includeInactive` option. Test the default on the simulator before a skill relies on it. (unverified)
- `ContentMarginGuide.container` gives the system margins. Apple's doc says they can differ on each side on iPhone Duo when a vertical bar sits next to the view. Use it instead of hard-coded margins.

## Arrangement: SwiftUI

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `ArrangementView` | SwiftUI | `struct ArrangementView<Primary, Secondary> : View where Primary : View, Secondary : View` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/arrangementview) |
| `ArrangementView.init(primary:secondary:)` | SwiftUI | `init(@ContentBuilder primary: () -> Primary, @ContentBuilder secondary: () -> Secondary)` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/arrangementview/init(primary:secondary:)) |
| `ArrangementView.init(_:)` | SwiftUI | `init(_ configuration: ArrangementViewStyleConfiguration)` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/arrangementview/init(_:)) |
| `View.arrangementViewStyle(_:)` | SwiftUI | `func arrangementViewStyle(_ style: some ArrangementViewStyle) -> some View` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/view/arrangementviewstyle(_:)) |
| `ArrangementViewStyle` | SwiftUI | `@preconcurrency @MainActor protocol ArrangementViewStyle` with `func makeBody(configuration: Self.Configuration) -> Self.Body` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/arrangementviewstyle) |
| `ArrangementViewStyleConfiguration` | SwiftUI | `struct ArrangementViewStyleConfiguration` with `var primary: Primary { get }`, `var secondary: Secondary { get }` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/arrangementviewstyleconfiguration) |
| `.automatic` | SwiftUI | `static var automatic: AutomaticArrangementViewStyle { get }` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/arrangementviewstyle/automatic) |
| `.split` | SwiftUI | `static var split: SplitArrangementViewStyle { get }` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/arrangementviewstyle/split) |
| `SplitArrangementViewStyle.axes(_:)` | SwiftUI | `func axes(_ axes: Axis.Set) -> SplitArrangementViewStyle` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/splitarrangementviewstyle/axes(_:)) |
| `.overlay` | SwiftUI | `static var overlay: OverlayArrangementViewStyle { get }` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/arrangementviewstyle/overlay) |
| `OverlayArrangementViewStyle.axes(_:)` | SwiftUI | `func axes(_ axes: Axis.Set) -> OverlayArrangementViewStyle` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/overlayarrangementviewstyle/axes(_:)) |
| `View.splitArrangementLayoutRatio(_:)` | SwiftUI | `func splitArrangementLayoutRatio(_ ratio: CGFloat?) -> some View` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/view/splitarrangementlayoutratio(_:)) |
| `View.splitArrangementLayoutRatio(minHorizontal:…)` | SwiftUI | `func splitArrangementLayoutRatio(minHorizontal: CGFloat? = nil, idealHorizontal: CGFloat? = nil, maxHorizontal: CGFloat? = nil, minVertical: CGFloat? = nil, idealVertical: CGFloat? = nil, maxVertical: CGFloat? = nil) -> some View` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/view/splitarrangementlayoutratio(minhorizontal:idealhorizontal:maxhorizontal:minvertical:idealvertical:maxvertical:)) |
| `View.splitArrangementLayoutSize(minWidth:…)` | SwiftUI | `func splitArrangementLayoutSize(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil, minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil) -> some View` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/view/splitarrangementlayoutsize(minwidth:idealwidth:maxwidth:minheight:idealheight:maxheight:)) |
| `View.splitArrangementFixedLayoutSize(horizontal:vertical:)` | SwiftUI | `func splitArrangementFixedLayoutSize(horizontal: Bool = true, vertical: Bool = true) -> some View` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/view/splitarrangementfixedlayoutsize(horizontal:vertical:)) |
| `EnvironmentValues.splitArrangementAxis` | SwiftUI | `var splitArrangementAxis: Axis? { get set }` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/environmentvalues/splitarrangementaxis) |
| `View.overlayArrangementEdge(_:)` | SwiftUI | `func overlayArrangementEdge(_ edge: HorizontalEdge?) -> some View` and `func overlayArrangementEdge(_ edge: VerticalEdge?) -> some View` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/view/overlayarrangementedge(_:)) |
| `EnvironmentValues.overlayArrangementZIndex` | SwiftUI | `var overlayArrangementZIndex: Int { get set }` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/environmentvalues/overlayarrangementzindex) |

- The default style, `.automatic`, resolves to a split arrangement.
- Use `.split` for two pieces of content you would otherwise put in an `HStack` or `VStack`. Use `.overlay` for content you would otherwise layer in a `ZStack`, such as player controls over video.
- Apple's overview says not to put an arrangement view inside a navigation split view, a list or a scroll view.

## Arrangement: UIKit

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `UIArrangementViewController` | UIKit | `class UIArrangementViewController : UIViewController` with `init()` | iOS 27.1, tvOS 27.1, visionOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller) |
| `setViewController(_:for:animated:)` | UIKit | `final func setViewController(_ viewController: UIViewController?, for placement: UIArrangementViewController.ViewPlacement, animated: Bool = false)` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller/setviewcontroller(_:for:animated:)) |
| `updateArrangement(_:animated:)` | UIKit | `final func updateArrangement<A>(_ arrangement: A, animated: Bool = false) where A : UIArrangementViewController.Arrangement` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller/updatearrangement(_:animated:)) |
| `state(for:)` | UIKit | `final func state(for placement: UIArrangementViewController.ViewPlacement) -> UIArrangementViewController.ViewState?` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller/state(for:)) |
| `viewController(for:)`, `placement(for:)` | UIKit | `final func viewController(for placement: UIArrangementViewController.ViewPlacement) -> UIViewController?` and `final func placement(for viewController: UIViewController) -> UIArrangementViewController.ViewPlacement?` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller/viewcontroller(for:)) |
| `UIArrangementViewController.ViewPlacement` | UIKit | `struct ViewPlacement : Equatable, Hashable, Sendable` with `static var primary`, `static var secondary` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller/viewplacement) |
| `UIArrangementViewController.ViewState` | UIKit | `struct ViewState` with `var zIndex: Int`, `var splitAxis: UIAxis`, `var isHidden: Bool` (all `get`) | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller/viewstate) |
| `UIArrangementViewController.Arrangement` | UIKit | `protocol Arrangement` with `associatedtype ViewProperties`, `var defaultViewProperties`, `mutating func setViewProperties(_:for:)`; static `.split`, `.overlay` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller/arrangement) |
| `UISplitArrangement` | UIKit | `struct UISplitArrangement` with `init()`, `func axes(_ axes: UIAxis) -> UISplitArrangement`, `ViewProperties` (`width`, `height`: `DimensionRange`; `layoutPriority: CGFloat`), `Dimension` (`.automatic`, `.intrinsic`, `.fractional(_:)`, `.absolute(_:)`) | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/uikit/uisplitarrangement-swift.struct) |
| `UIOverlayArrangement` | UIKit | `struct UIOverlayArrangement` with `init()`, `func axes(_ axes: UIAxis) -> UIOverlayArrangement`, `ViewProperties` (`edge: NSDirectionalRectEdge`) | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/uikit/uioverlayarrangement-swift.struct) |
| `UIViewController.arrangementViewController` | UIKit | `var arrangementViewController: UIArrangementViewController? { get }` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiviewcontroller/arrangementviewcontroller) |

- In Swift, `UISplitArrangement` and `UIOverlayArrangement` are value types. Change a copy, then pass it to `updateArrangement(_:animated:)`.
- `updateArrangement(.split.axes(.horizontal))` works because `.split` and `.overlay` are static members on the `Arrangement` protocol.

## Hinge

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `View.onHingeChange(isEnabled:_:)` | SwiftUI | `func onHingeChange(isEnabled: Bool = true, _ action: @escaping (_ oldContext: DeviceHingeContext, _ newContext: DeviceHingeContext) -> Void) -> some View` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/view/onhingechange(isenabled:_:)) |
| `DeviceHingeContext` | SwiftUI | `struct DeviceHingeContext : Equatable, Sendable` with `var hinge: DeviceHinge?` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/devicehingecontext) |
| `DeviceHinge` | SwiftUI | `struct DeviceHinge : Hashable, Sendable` with `var status: DeviceHinge.Status`, `var angle: Angle` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/devicehinge) |
| `DeviceHinge.Status` | SwiftUI | `struct Status : Hashable, Sendable` with `static var closed`, `static var partiallyOpen`, `static var fullyOpen` | iOS 27.1 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/devicehinge/status-swift.struct) |
| `UIHingeInteraction` | UIKit | `class UIHingeInteraction : NSObject, UIInteraction` with `init(updateHandler: @escaping (UIHingeInteraction, UIHingeInteraction.Update) -> Void)`, `var isEnabled: Bool` | iOS 27.1, tvOS 27.1, visionOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uihingeinteraction) |
| `UIHingeInteraction.Update` | UIKit | `class Update` with `var hinge: UIHinge? { get }` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uihingeinteraction/update) |
| `UIHinge` | UIKit | `class UIHinge : NSObject, NSCopying` with `var status: UIHinge.Status { get }`, `var angle: CGFloat { get }` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uihinge) |
| `UIHinge.Status` | UIKit | `enum Status : Int` with `.unknown`, `.closed`, `.partiallyOpen`, `.fullyOpen` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uihinge/status-swift.enum) |

- `hinge` is `nil` when the view hierarchy has no hinge to report.
- SwiftUI gives `angle` as an `Angle`. UIKit gives a `CGFloat` in radians.
- `DeviceHinge.Status` is a struct, not an enum. Compare with `==`; a `switch` needs a `default`.
- UIKit's header says the update rate and precision of the angle can change. Prefer `status` when you only need closed, partly open or open.
- There is no posture API. Lay out with arrangements, size classes and reserved regions. Use the hinge for effects.

## Scenes and scene accessories

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `View.sceneAccessory(content:)` | SwiftUI | `func sceneAccessory<C>(@ContentBuilder content: () -> C) -> some View where C : SceneAccessoryContent` | iOS 27.0; not on Mac Catalyst, macOS, tvOS, watchOS, visionOS | [doc](https://developer.apple.com/documentation/swiftui/view/sceneaccessory(content:)) |
| `SceneAccessoryContent` | SwiftUI | `@MainActor protocol SceneAccessoryContent` with `associatedtype Body : SceneAccessoryContent` | iOS 27.0 | [doc](https://developer.apple.com/documentation/swiftui/sceneaccessorycontent) |
| `SceneAccessoryContent.onAvailabilityChange(perform:)` | SwiftUI | `func onAvailabilityChange(perform action: @escaping (_ isAvailable: Bool) -> Void) -> some SceneAccessoryContent` | iOS 27.0 | [doc](https://developer.apple.com/documentation/swiftui/sceneaccessorycontent/onavailabilitychange(perform:)) |
| `CameraCaptureAccessory` | SwiftUI | `struct CameraCaptureAccessory<Content> : SceneAccessoryContent where Content : View` with `init(@ContentBuilder content: @escaping () -> Content)` and `init(isEnabled: Binding<Bool>, @ContentBuilder content: @escaping () -> Content)` | iOS 27.1 | [doc](https://developer.apple.com/documentation/swiftui/cameracaptureaccessory) |
| `ExternalNonInteractiveAccessory` | SwiftUI | `struct ExternalNonInteractiveAccessory<Content> : SceneAccessoryContent where Content : View` with the same two initializers | iOS 27.0 | [doc](https://developer.apple.com/documentation/swiftui/externalnoninteractiveaccessory) |
| `UISceneAccessory.cameraCapture(sceneConfiguration:)` | UIKit | `class func cameraCapture(sceneConfiguration: UISceneConfiguration) -> Self` (also `cameraCapture(sceneConfiguration:userInfo:)`) | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uisceneaccessory/cameracapture(sceneconfiguration:)) |
| `UISceneAccessory.externalNonInteractive(sceneConfiguration:)` | UIKit | `class func externalNonInteractive(sceneConfiguration: UISceneConfiguration) -> Self` (also with `userInfo:`) | iOS 27.0 | [doc](https://developer.apple.com/documentation/uikit/uisceneaccessory/externalnoninteractive(sceneconfiguration:)) |
| `UIViewController.registerSceneAccessory(_:)` | UIKit | `func registerSceneAccessory(_ accessory: UISceneAccessory) -> UISceneAccessoryRegistration` | iOS 27.0 | [doc](https://developer.apple.com/documentation/uikit/uiviewcontroller/registersceneaccessory(_:)) |
| `UIViewController.unregisterSceneAccessory(_:)` | UIKit | `func unregisterSceneAccessory(_ registration: UISceneAccessoryRegistration)` | iOS 27.0 | [doc](https://developer.apple.com/documentation/uikit/uiviewcontroller/unregistersceneaccessory(_:)) |
| `UISceneAccessoryRegistration` | UIKit | `class UISceneAccessoryRegistration` with `var isAvailable: Bool { get }`, `var isEnabled: Bool { get set }` | iOS 27.0 | [doc](https://developer.apple.com/documentation/uikit/uisceneaccessoryregistration) |
| `UIScene.ConnectionOptions.sceneAccessoryUserInfo` | UIKit | `var sceneAccessoryUserInfo: Any? { get }` | iOS 27.0 | [doc](https://developer.apple.com/documentation/uikit/uiscene/connectionoptions/sceneaccessoryuserinfo) |
| `UISceneSession.Role.windowCameraCaptureAccessory` | UIKit | `static let windowCameraCaptureAccessory: UISceneSession.Role` | iOS 27.1 | [doc](https://developer.apple.com/documentation/uikit/uiscenesession/role-swift.struct/windowcameracaptureaccessory) |
| `UIWindowScene.ActivationAction` | UIKit | `class ActivationAction : UIAction` (Objective-C name `UIWindowSceneActivationAction`) | iOS 15.0 | [doc](https://developer.apple.com/documentation/uikit/uiwindowscene/activationaction) |

- The system decides when and where to show an accessory. The app must work without it.
- Apple's overview says the camera capture accessory can show content on the outer display while the phone is fully open and the app captures with the rear camera.
- The system sets the `windowCameraCaptureAccessory` role on scenes it creates for a camera capture accessory. Read it; don't set it.
- Apple's guide: [Registering a camera capture accessory on iPhone Duo](https://developer.apple.com/documentation/avfoundation/registering-a-camera-capture-accessory-on-iphone-duo).

## Camera

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `AVCaptureDevice.DeviceType.builtInOuterUltraWideCamera` | AVFoundation | `static let builtInOuterUltraWideCamera: AVCaptureDevice.DeviceType` | iOS 27.1 only | [doc](https://developer.apple.com/documentation/avfoundation/avcapturedevice/devicetype-swift.struct/builtinouterultrawidecamera) |
| `AVCaptureDevice.DeviceType.builtInInnerUltraWideCamera` | AVFoundation | `static let builtInInnerUltraWideCamera: AVCaptureDevice.DeviceType` | iOS 27.1 only | [doc](https://developer.apple.com/documentation/avfoundation/avcapturedevice/devicetype-swift.struct/builtininnerultrawidecamera) |
| `AVCaptureDeviceDirectionCoordinator` | **AVKit** | `class AVCaptureDeviceDirectionCoordinator : NSObject` with `init(view: UIView, deviceTypes: [AVCaptureDevice.DeviceType], changeHandler: ((AVCaptureDeviceDirectionMap) -> Void)? = nil)` | iOS 27.1, Mac Catalyst 27.1 | [doc](https://developer.apple.com/documentation/avkit/avcapturedevicedirectioncoordinator) |
| `AVCaptureDeviceDirectionCoordinator.deviceDirections` | AVKit | `var deviceDirections: AVCaptureDeviceDirectionMap { get }` | iOS 27.1 | [doc](https://developer.apple.com/documentation/avkit/avcapturedevicedirectioncoordinator/devicedirections) |
| `AVCaptureDeviceDirectionMap` | AVKit | `class AVCaptureDeviceDirectionMap : NSObject, @unchecked Sendable` with `var forwardFacingDeviceDescriptors: [AVCaptureDeviceDescriptor] { get }`, `var backwardFacingDeviceDescriptors: [AVCaptureDeviceDescriptor] { get }` | iOS 27.1 | [doc](https://developer.apple.com/documentation/avkit/avcapturedevicedirectionmap) |
| `AVCaptureDeviceDescriptor` | AVKit | `class AVCaptureDeviceDescriptor : NSObject, @unchecked Sendable` with `deviceType`, `mediaTypes`, `position`, `uniqueID`, `localizedName` | iOS 27.1 | [doc](https://developer.apple.com/documentation/avkit/avcapturedevicedescriptor) |
| `AVCaptureDevice.RotationCoordinator` | AVFoundation | `class RotationCoordinator` with `init(device: AVCaptureDevice, previewLayer: CALayer?)`, `videoRotationAngleForHorizonLevelPreview`, `videoRotationAngleForHorizonLevelCapture` | iOS 17.0 | [doc](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator) |
| `RotationCoordinator.videoRotationAngleRelative(toDeviceOrientation:)` | AVFoundation | `func videoRotationAngleRelative(toDeviceOrientation deviceOrientation: AVCaptureVideoOrientation) -> CGFloat` | iOS 27.0 | [doc](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator/videorotationanglerelative(todeviceorientation:)) |
| `AVCaptureDevice.dynamicAspectRatio` | AVFoundation | `var dynamicAspectRatio: AVCaptureDevice.AspectRatio? { get }` | iOS 26.0 | [doc](https://developer.apple.com/documentation/avfoundation/avcapturedevice/dynamicaspectratio) |
| `AVCaptureDevice.setDynamicAspectRatio(_:completionHandler:)` | AVFoundation | `func setDynamicAspectRatio(_ dynamicAspectRatio: AVCaptureDevice.AspectRatio, completionHandler handler: (@Sendable (CMTime, (any Error)?) -> Void)? = nil)` (also `async throws -> CMTime`) | iOS 26.0 | [doc](https://developer.apple.com/documentation/avfoundation/avcapturedevice/setdynamicaspectratio(_:completionhandler:)) |
| `AVCaptureDevice.Format.supportedDynamicAspectRatios` | AVFoundation | `var supportedDynamicAspectRatios: [AVCaptureDevice.AspectRatio] { get }` | iOS 26.0 | [doc](https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/supporteddynamicaspectratios) |
| `AVCapturePhotoOutput.isCameraSensorOrientationCompensationEnabled` | AVFoundation | `var isCameraSensorOrientationCompensationEnabled: Bool { get set }` (check `isCameraSensorOrientationCompensationSupported` first) | iOS 26.0 | [doc](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/iscamerasensororientationcompensationenabled) |

- `import AVKit` for the direction coordinator. It is not in AVFoundation.
- Apple's guide says a discovery session for `.builtInWideAngleCamera` or `.builtInUltraWideCamera` at `.front` returns the virtual front camera on iPhone Duo. It is a virtual device, so `isVirtualDevice` is `true`.
- The coordinator ignores the virtual front camera. List the two physical front cameras instead.
- "Forward facing" means facing the same way as the view you pass in, not `position == .front`. After a fold, a rear camera can face forward.
- Apple's guide: [Choosing a camera by the direction it faces](https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces).

## iOS 27 SwiftUI (WWDC26)

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `DynamicViewContent.reorderable()` | SwiftUI | `func reorderable() -> some DynamicViewContent<Self.Data>` (also `reorderable(collectionID:)`) | iOS 27.0; not tvOS | [doc](https://developer.apple.com/documentation/swiftui/dynamicviewcontent/reorderable()) |
| `View.reorderContainer(for:isEnabled:move:)` | SwiftUI | `func reorderContainer<Item>(for item: Item.Type, isEnabled: Bool = true, move: @escaping (_ difference: ReorderDifference<Item.ID, ReorderableSingleCollectionIdentifier>) -> ()) -> some View where Item : Identifiable, Item.ID : Sendable` | iOS 27.0; not tvOS | [doc](https://developer.apple.com/documentation/swiftui/view/reordercontainer(for:isenabled:move:)) |
| `ReorderDifference` | SwiftUI | `struct ReorderDifference<ItemID, CollectionID>` | iOS 27.0 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/reorderdifference) |
| `View.swipeActionsContainer()` | SwiftUI | `func swipeActionsContainer() -> some View` | iOS 27.0; not tvOS | [doc](https://developer.apple.com/documentation/swiftui/view/swipeactionscontainer()) |
| `View.swipeActions(edge:allowsFullSwipe:content:onPresentationChanged:)` | SwiftUI | `func swipeActions(edge: HorizontalEdge = .trailing, allowsFullSwipe: Bool = true, @ContentBuilder content: () -> some View, onPresentationChanged: @escaping (Bool) -> Void) -> some View` | iOS 27.0; not tvOS | [doc](https://developer.apple.com/documentation/swiftui/view/swipeactions(edge:allowsfullswipe:content:onpresentationchanged:)) |
| `TabRole.prominent` | SwiftUI | `static var prominent: TabRole { get }` | iOS 27.0 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/tabrole/prominent) |
| `View.toolbarMinimizationBehavior(_:for:)` | SwiftUI | `func toolbarMinimizationBehavior(_ behavior: ToolbarMinimizationBehavior, for bars: ToolbarPlacement...) -> some View` | iOS 27.0 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/view/toolbarminimizationbehavior(_:for:)) |
| `View.tabBarMinimizeBehavior(_:)` | SwiftUI | `func tabBarMinimizeBehavior(_ behavior: TabBarMinimizeBehavior) -> some View` | iOS 26.0 | [doc](https://developer.apple.com/documentation/swiftui/view/tabbarminimizebehavior(_:)) |
| `View.alert(_:item:actions:)` | SwiftUI | `func alert<A, T>(_ titleKey: LocalizedStringKey, item data: Binding<T?>, @ContentBuilder actions: (T) -> A) -> some View where A : View` (also with `message:`) | iOS 15.0, new in the iOS 27 SDK | [doc](https://developer.apple.com/documentation/swiftui/view/alert(_:item:actions:)) |
| `View.confirmationDialog(_:item:titleVisibility:actions:)` | SwiftUI | `func confirmationDialog<A, T>(_ titleKey: LocalizedStringKey, item data: Binding<T?>, titleVisibility: Visibility = .automatic, @ContentBuilder actions: (T) -> A) -> some View where A : View` (also with `message:`) | iOS 15.0, new in the iOS 27 SDK | [doc](https://developer.apple.com/documentation/swiftui/view/confirmationdialog(_:item:titlevisibility:actions:)) |
| `@State` macro | SwiftUI | `` @attached(accessor, names: named(init), named(get), named(set)) @attached(peer, names: prefixed(`_`), prefixed(__), prefixed(`$`)) macro State() `` (also `State(initialValue:)`, `State(wrappedValue:)`) | no `@available` limit, new in the iOS 27 SDK | [doc](https://developer.apple.com/documentation/swiftui/state()) |
| `ContentBuilder` | SwiftUI | `typealias ContentBuilder = ViewBuilder` | iOS 13.0, new in the iOS 27 SDK | [doc](https://developer.apple.com/documentation/swiftui/contentbuilder) |
| `AsyncImage.init(request:scale:)` | SwiftUI | `init(request: URLRequest, scale: CGFloat = 1) where Content == Image` (also with `content:placeholder:` and `transaction:content:`) | iOS 27.0 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/asyncimage/init(request:scale:)) |

- "New in the iOS 27 SDK" means the symbol is in the iOS 27.1 SDK and absent from the iOS 26.5 SDK in Xcode 26.5 (17F42). The `alert` and `confirmationDialog` overloads are inlined into client code, so they build for iOS 15 targets. We typechecked them at an iOS 15.0 target.
- `swipeActionsContainer()` gives custom `ScrollView` or `LazyVStack` rows the one-open-row behaviour that `List` has built in.
- Apple explains the source changes that `@State` and `ContentBuilder` can cause in [TN3211](https://developer.apple.com/documentation/technotes/tn3211-resolving-swiftui-source-incompatibilities-for-state-and-contentbuilder).

## Liquid Glass and corners

Used by `duo-design-system`, `duo-ergonomics` and the gallery app. None of these are new for iPhone Duo: they arrived with the iOS 26 design.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `View.glassEffect(_:in:)` | SwiftUI | `func glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape()) -> some View` | iOS 26.0; not visionOS | [doc](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)) |
| `Glass` | SwiftUI | `struct Glass : Equatable, Sendable` with `static var regular`, `static var clear`, `func tint(_ color: Color?) -> Glass`, `func interactive(_ isEnabled: Bool = true) -> Glass` | iOS 26.0; not visionOS | [doc](https://developer.apple.com/documentation/swiftui/glass) |
| `GlassEffectContainer` | SwiftUI | `struct GlassEffectContainer<Content> : View where Content : View` with `init(spacing: CGFloat? = nil, @ContentBuilder content: () -> Content)` | iOS 26.0; not visionOS | [doc](https://developer.apple.com/documentation/swiftui/glasseffectcontainer) |
| `.glass`, `.glassProminent` button styles | SwiftUI | `static var glass: GlassButtonStyle` and `static var glassProminent: GlassProminentButtonStyle` on `PrimitiveButtonStyle` | iOS 26.0; not visionOS | [doc](https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glass) |
| `View.scrollEdgeEffectStyle(_:for:)` | SwiftUI | `func scrollEdgeEffectStyle(_ style: ScrollEdgeEffectStyle?, for edges: Edge.Set) -> some View`; the style has `.automatic`, `.hard`, `.soft` | iOS 26.0; not visionOS | [doc](https://developer.apple.com/documentation/swiftui/view/scrolledgeeffectstyle(_:for:)) |
| `View.safeAreaBar(edge:alignment:spacing:content:)` | SwiftUI | `func safeAreaBar(edge: VerticalEdge, alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ContentBuilder content: () -> some View) -> some View` (also a `HorizontalEdge` overload) | iOS 26.0 | [doc](https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:)) |
| `View.containerShape(_:)` | SwiftUI | `func containerShape(_ shape: some RoundedRectangularShape) -> some View` and the older `func containerShape<T>(_ shape: T) -> some View where T : InsettableShape` | iOS 26.0 (`RoundedRectangularShape`); iOS 15.0 (`InsettableShape`) | [doc](https://developer.apple.com/documentation/swiftui/view/containershape(_:)) |
| `RoundedRectangularShape` | SwiftUI | `protocol RoundedRectangularShape : InsettableShape` | iOS 26.0 | [doc](https://developer.apple.com/documentation/swiftui/roundedrectangularshape) |
| `Edge.Corner.Style` | SwiftUI | `static func concentric(minimum: Edge.Corner.Style? = nil) -> Edge.Corner.Style`, `static func fixed(_ radius: CGFloat) -> Edge.Corner.Style` | iOS 26.0 | [doc](https://developer.apple.com/documentation/swiftui/edge/corner/style) |
| `ConcentricRectangle.init(uniformTopCorners:uniformBottomCorners:)` | SwiftUI | `init(uniformTopCorners: Edge.Corner.Style = .concentric, uniformBottomCorners: Edge.Corner.Style = .concentric)`; also `Shape.rect(corners:isUniform:)` where `Self == ConcentricRectangle` | iOS 26.0 | [doc](https://developer.apple.com/documentation/swiftui/concentricrectangle/init(uniformtopcorners:uniformbottomcorners:)) |
| `RectangleCornerRadii` | SwiftUI | `struct RectangleCornerRadii`; used by `Path(roundedRect:cornerRadii:style:)` and `GeometryProxy.concentricCornerRadii` | iOS 16.0 | [doc](https://developer.apple.com/documentation/swiftui/rectanglecornerradii) |
| `UIGlassEffect` | UIKit | `class UIGlassEffect : UIVisualEffect` with `init(style: UIGlassEffect.Style)`, `var isInteractive: Bool`, `var tintColor: UIColor?` | iOS 26.0 | [doc](https://developer.apple.com/documentation/uikit/uiglasseffect) |
| `UIButton.Configuration.glass()`, `.prominentGlass()` | UIKit | `static func glass() -> UIButton.Configuration`, `static func prominentGlass() -> UIButton.Configuration` | iOS 26.0; not watchOS, visionOS | [doc](https://developer.apple.com/documentation/uikit/uibutton/configuration-swift.struct/glass()) |
| `UICornerConfiguration.corners(radius:)`, `.capsule(maximumRadius:)` | UIKit | `static func corners(radius: UICornerRadius) -> UICornerConfiguration`, `static func capsule(maximumRadius: Double? = nil) -> UICornerConfiguration` | iOS 26.0 | [doc](https://developer.apple.com/documentation/uikit/uicornerconfiguration-swift.struct/corners(radius:)) |
| `UICornerRadius` | UIKit | `static func containerConcentric(minimum: CGFloat? = nil) -> UICornerRadius`, `static func fixed(_ radius: Double) -> UICornerRadius` | iOS 26.0 | [doc](https://developer.apple.com/documentation/uikit/uicornerradius-swift.struct) |
| `UIView.effectiveRadius(corner:)` | UIKit | `func effectiveRadius(corner: UIRectCorner) -> CGFloat` | iOS 26.0 | [doc](https://developer.apple.com/documentation/uikit/uiview/effectiveradius(corner:)) |

- Only the iOS 26 `containerShape(_:)` overload, which takes a `RoundedRectangularShape`, gives `GeometryProxy.concentricCornerRadii` a container to measure against (`duo-design-system` references/corners.md).
- `UIView.effectiveRadius(corner:)` reads back the radius the view's `cornerConfiguration` resolves to. Called inside `layoutSubviews()` or `updateProperties()`, it is invalidated when that radius changes (UIKit header).

## Type, size and touch targets

Standard SwiftUI and UIKit APIs the v0.2 design, ergonomics and accessibility skills use. Not Duo-specific.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `ScaledMetric` | SwiftUI | `@propertyWrapper struct ScaledMetric<Value> where Value : BinaryFloatingPoint` with `init(wrappedValue: Value, relativeTo textStyle: Font.TextStyle)` | iOS 14.0 | [doc](https://developer.apple.com/documentation/swiftui/scaledmetric) |
| `Font.custom(_:size:relativeTo:)` | SwiftUI | `static func custom(_ name: String, size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font` | iOS 14.0 | [doc](https://developer.apple.com/documentation/swiftui/font/custom(_:size:relativeto:)) |
| `DynamicTypeSize.isAccessibilitySize` | SwiftUI | `var isAccessibilitySize: Bool { get }`; read the current size from `EnvironmentValues.dynamicTypeSize` | iOS 15.0 | [doc](https://developer.apple.com/documentation/swiftui/dynamictypesize/isaccessibilitysize) |
| `ViewThatFits` | SwiftUI | `struct ViewThatFits<Content> : View where Content : View` with `init(in axes: Axis.Set = [.horizontal, .vertical], @ContentBuilder content: () -> Content)` | iOS 16.0 | [doc](https://developer.apple.com/documentation/swiftui/viewthatfits) |
| `AnyLayout`, `HStackLayout`, `VStackLayout` | SwiftUI | `struct AnyLayout : Layout, Sendable` with `init<L>(_ layout: L) where L : Layout` | iOS 16.0 | [doc](https://developer.apple.com/documentation/swiftui/anylayout) |
| `View.onGeometryChange(for:of:action:)` | SwiftUI | `func onGeometryChange<T>(for type: T.Type, of transform: @escaping @Sendable (GeometryProxy) -> T, action: @escaping (_ newValue: T) -> Void) -> some View where T : Equatable` | iOS 16.0 (back-deployed); the `(oldValue, newValue)` form is iOS 18.0 | [doc](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)) |
| `View.contentShape(_:eoFill:)` | SwiftUI | `func contentShape<S>(_ shape: S, eoFill: Bool = false) -> some View where S : Shape` | iOS 13.0 | [doc](https://developer.apple.com/documentation/swiftui/view/contentshape(_:eofill:)) |
| `View.controlSize(_:)`, `ControlSize.extraLarge` | SwiftUI | `func controlSize(_ controlSize: ControlSize) -> some View`; `case extraLarge` | iOS 15.0; `.extraLarge` iOS 17.0 | [doc](https://developer.apple.com/documentation/swiftui/view/controlsize(_:)) |
| `UIFontMetrics.scaledValue(for:compatibleWith:)` | UIKit | `func scaledValue(for value: CGFloat, compatibleWith traitCollection: UITraitCollection?) -> CGFloat` | iOS 11.0 | [doc](https://developer.apple.com/documentation/uikit/uifontmetrics/scaledvalue(for:compatiblewith:)) |
| `UIButton.Configuration.buttonSize` | UIKit | `var buttonSize: UIButton.Configuration.Size` | iOS 15.0 | [doc](https://developer.apple.com/documentation/uikit/uibutton/configuration-swift.struct/buttonsize) |
| `UIView.effectiveUserInterfaceLayoutDirection` | UIKit | `var effectiveUserInterfaceLayoutDirection: UIUserInterfaceLayoutDirection { get }` | iOS 10.0 | [doc](https://developer.apple.com/documentation/uikit/uiview/effectiveuserinterfacelayoutdirection) |

- Apple's minimum hit region is 44 x 44 pt ([HIG: Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)). In SwiftUI, put the frame and `contentShape` inside the button's label. With them outside the `Button`, clicks off the glyph did nothing in a SwiftUI check on the Mac; iOS taps are unverified (`duo-ergonomics` references/measured.md).

## Scenes and windows

Used by `duo-scenes`. Most of these date from iOS 13 to iOS 17; iPhone Duo is the first iPhone where more than one window matters.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `UIApplication.activateSceneSession(for:errorHandler:)` | UIKit | `func activateSceneSession(for request: UISceneSessionActivationRequest, errorHandler: ((any Error) -> Void)? = nil)` | iOS 17.0 | [doc](https://developer.apple.com/documentation/uikit/uiapplication/activatescenesession(for:errorhandler:)) |
| `UISceneSessionActivationRequest` | UIKit | `struct UISceneSessionActivationRequest : Hashable` with `init(role: UISceneSession.Role = .windowApplication, userActivity: NSUserActivity? = nil, options: UIScene.ActivationRequestOptions? = nil)` and `init(session:userActivity:options:)` | iOS 17.0 | [doc](https://developer.apple.com/documentation/uikit/uiscenesessionactivationrequest-swift.struct) |
| `UIApplication.requestSceneSessionActivation(_:userActivity:options:errorHandler:)` | UIKit | `func requestSceneSessionActivation(_ sceneSession: UISceneSession?, userActivity: NSUserActivity?, options: UIScene.ActivationRequestOptions?, errorHandler: ((any Error) -> Void)? = nil)` | iOS 13.0; the SDK marks it to be deprecated in favour of `activateSceneSession(for:errorHandler:)`, and Apple's doc page lists it as deprecated in iOS 27.0 | [doc](https://developer.apple.com/documentation/uikit/uiapplication/requestscenesessionactivation(_:useractivity:options:errorhandler:)) |
| `UISceneError.Code` | UIKit | `enum Code : Int` with `.multipleScenesNotSupported`, `.requestDenied` | iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uisceneerror/code) |
| `UIApplication.supportsMultipleScenes`, `openSessions`, `connectedScenes` | UIKit | `var supportsMultipleScenes: Bool { get }`, `var openSessions: Set<UISceneSession> { get }`, `var connectedScenes: Set<UIScene> { get }` | iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uiapplication/supportsmultiplescenes) |
| `UIApplicationSupportsMultipleScenes` | Info.plist key | Boolean inside `UIApplicationSceneManifest` | iOS 13.0 | [doc](https://developer.apple.com/documentation/bundleresources/information-property-list/uiapplicationscenemanifest/uiapplicationsupportsmultiplescenes) |
| `UIWindowScene.ActivationAction.init(title:subtitle:image:identifier:discoverabilityTitle:attributes:alternate:_:)` | UIKit | `convenience init(title: String? = nil, subtitle: String? = nil, image: UIImage? = nil, identifier: UIAction.Identifier? = nil, discoverabilityTitle: String? = nil, attributes: UIMenuElement.Attributes = [], alternate: UIAction? = nil, _ configuration: @escaping UIWindowScene.ActivationAction.ConfigurationProvider)` | iOS 15.0 | [doc](https://developer.apple.com/documentation/uikit/uiwindowscene/activationaction) |
| `UIWindowScene.ActivationConfiguration` | UIKit | `class ActivationConfiguration : NSObject` with `convenience init(userActivity: NSUserActivity, options: UIWindowScene.ActivationRequestOptions? = nil, preview: UITargetedPreview? = nil)` | iOS 15.0 | [doc](https://developer.apple.com/documentation/uikit/uiwindowscene/activationconfiguration) |
| `UISceneActivationConditions` | UIKit | `class UISceneActivationConditions : NSObject, NSSecureCoding` with `var canActivateForTargetContentIdentifierPredicate: NSPredicate`, `var prefersToActivateForTargetContentIdentifierPredicate: NSPredicate`; pairs with `NSUserActivity.targetContentIdentifier` | iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uisceneactivationconditions) |
| `UIWindowScene.closureConfirmation` | UIKit | `var closureConfirmation: UISceneClosureConfirmation? { get set }`; `class UISceneClosureConfirmation : NSObject, NSCopying, NSSecureCoding` | iOS 27.0; not tvOS, watchOS, visionOS | [doc](https://developer.apple.com/documentation/uikit/uiwindowscene/closureconfirmation) |
| `UIWindowSceneDelegate.windowScene(_:didUpdateEffectiveGeometry:)` | UIKit | `optional func windowScene(_ windowScene: UIWindowScene, didUpdateEffectiveGeometry previousEffectiveGeometry: UIWindowScene.Geometry)`; reads `UIWindowScene.effectiveGeometry` (iOS 16.0) | iOS 26.0 | [doc](https://developer.apple.com/documentation/uikit/uiwindowscenedelegate/windowscene(_:didupdateeffectivegeometry:)) |
| `UIWindowScene.displayLink(target:selector:)` | UIKit | `func displayLink(target: Any, selector: Selector) -> CADisplayLink?` | iOS 27.0; `UIScreen.displayLink(withTarget:selector:)` is deprecated in iOS 27.0 | [doc](https://developer.apple.com/documentation/uikit/uiwindowscene/displaylink(target:selector:)) |
| `UISceneDelegate.stateRestorationActivity(for:)` | UIKit | `optional func stateRestorationActivity(for scene: UIScene) -> NSUserActivity?`; also `UISceneSession.stateRestorationActivity`, `UISceneSession.userInfo`, `UIScene.ConnectionOptions.userActivities` | iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uiscenedelegate/staterestorationactivity(for:)) |
| `UISceneDelegate.sceneDidBecomeActive(_:)` | UIKit | `optional func sceneDidBecomeActive(_ scene: UIScene)` | iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uiscenedelegate/scenedidbecomeactive(_:)) |
| `UIApplicationDelegate.application(_:didDiscardSceneSessions:)` | UIKit | `optional func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>)` | iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:diddiscardscenesessions:)) |
| `UIViewController.updateProperties()`, `setNeedsUpdateProperties()` | UIKit | `func updateProperties()`, `func setNeedsUpdateProperties()` | iOS 26.0 | [doc](https://developer.apple.com/documentation/uikit/uiviewcontroller/updateproperties()) |
| `EnvironmentValues.supportsMultipleWindows` | SwiftUI | `var supportsMultipleWindows: Bool { get }` | iOS 16.0 | [doc](https://developer.apple.com/documentation/swiftui/environmentvalues/supportsmultiplewindows) |
| `OpenWindowAction`, `DismissWindowAction` | SwiftUI | `struct OpenWindowAction` (`EnvironmentValues.openWindow`) and `struct DismissWindowAction` (`EnvironmentValues.dismissWindow`) | iOS 16.0; `DismissWindowAction` iOS 17.0 | [doc](https://developer.apple.com/documentation/swiftui/openwindowaction) |
| `WindowGroup.init(_:for:content:)` | SwiftUI | `init<D, C>(_ title: Text, for type: D.Type, @ContentBuilder content: @escaping (Binding<D?>) -> C)` (also with a title key or string) | iOS 16.0 | [doc](https://developer.apple.com/documentation/swiftui/windowgroup) |
| `SceneStorage` | SwiftUI | `@propertyWrapper struct SceneStorage<Value> : DynamicProperty` | iOS 14.0 | [doc](https://developer.apple.com/documentation/swiftui/scenestorage) |
| `View.onChange(of:initial:_:)` | SwiftUI | `func onChange<V>(of value: V, initial: Bool = false, _ action: @escaping (_ oldValue: V, _ newValue: V) -> Void) -> some View where V : Equatable` | iOS 17.0 | [doc](https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:)) |

- `EnvironmentValues.supportsMultipleWindows` doc still names only iPadOS and macOS as true. `duo-scenes` records what the iPhone Duo simulator returned.
- Pass an `errorHandler` (or an `alternate:` action) every time. A new-window request can fail with `UISceneError.Code` on a phone, and `duo-scenes` explains which initializer to avoid.

## Accessibility

Used by `duo-accessibility`, `duo-postures`, `duo-transitions` and `duo-ergonomics`. Not Duo-specific.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `View.accessibilityElement(children:)` | SwiftUI | `func accessibilityElement(children: AccessibilityChildBehavior = .ignore) -> some View`; behaviours `.ignore`, `.combine`, `.contain` | iOS 13.0 | [doc](https://developer.apple.com/documentation/swiftui/view/accessibilityelement(children:)) |
| `View.accessibilitySortPriority(_:)` | SwiftUI | `func accessibilitySortPriority(_ sortPriority: Double) -> ModifiedContent<Self, AccessibilityAttachmentModifier>` | iOS 14.0 | [doc](https://developer.apple.com/documentation/swiftui/view/accessibilitysortpriority(_:)) |
| `AccessibilityFocusState`, `View.accessibilityFocused(_:equals:)` | SwiftUI | `@propertyWrapper struct AccessibilityFocusState<Value> : DynamicProperty where Value : Hashable`; `func accessibilityFocused<Value>(_ binding: AccessibilityFocusState<Value>.Binding, equals value: Value) -> some View where Value : Hashable` | iOS 15.0 | [doc](https://developer.apple.com/documentation/swiftui/accessibilityfocusstate) |
| `View.accessibilityInputLabels(_:)` | SwiftUI | `func accessibilityInputLabels(_ inputLabels: [Text]) -> ModifiedContent<Self, AccessibilityAttachmentModifier>` (also `LocalizedStringKey` and `StringProtocol` forms) | iOS 14.0 | [doc](https://developer.apple.com/documentation/swiftui/view/accessibilityinputlabels(_:)) |
| `View.accessibilityAction(named:_:)` | SwiftUI | `func accessibilityAction(named name: Text, _ handler: @escaping () -> Void) -> ModifiedContent<Self, AccessibilityAttachmentModifier>` (also key, string and `LocalizedStringResource` forms) | iOS 13.0; the `LocalizedStringResource` form iOS 16.0 | [doc](https://developer.apple.com/documentation/swiftui/view/accessibilityaction(named:_:)) |
| `View.accessibilityShowsLargeContentViewer(_:)` | SwiftUI | `func accessibilityShowsLargeContentViewer<V>(@ContentBuilder _ largeContentView: () -> V) -> some View where V : View` (also a form with no arguments) | iOS 15.0 | [doc](https://developer.apple.com/documentation/swiftui/view/accessibilityshowslargecontentviewer(_:)) |
| `View.accessibilityRotor(_:entries:)` | SwiftUI | `func accessibilityRotor<Content>(_ label: Text, @ContentBuilder entries: @escaping () -> Content) -> some View where Content : AccessibilityRotorContent` | iOS 15.0 | [doc](https://developer.apple.com/documentation/swiftui/view/accessibilityrotor(_:entries:)) |
| `View.accessibilityAddTraits(_:)`, `accessibilityHidden(_:)` | SwiftUI | `func accessibilityAddTraits(_ traits: AccessibilityTraits) -> ModifiedContent<Self, AccessibilityAttachmentModifier>`; `func accessibilityHidden(_ hidden: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier>` | iOS 14.0 | [doc](https://developer.apple.com/documentation/swiftui/view/accessibilityaddtraits(_:)) |
| Accessibility settings in `EnvironmentValues` | SwiftUI | `accessibilityReduceMotion`, `accessibilityReduceTransparency`, `accessibilityDifferentiateWithoutColor`, `accessibilitySwitchControlEnabled`, `accessibilityVoiceOverEnabled` (all `Bool { get }`); `colorSchemeContrast: ColorSchemeContrast { get }` | iOS 13.0; `accessibilitySwitchControlEnabled` and `accessibilityVoiceOverEnabled` iOS 14.0 and 15.0 | [doc](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion) |
| `EnvironmentValues.accessibilityPrefersCrossFadeTransitions` | SwiftUI | `var accessibilityPrefersCrossFadeTransitions: Bool { get }` | iOS 26.4 | [doc](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilitypreferscrossfadetransitions) |
| `View.keyboardShortcut(_:modifiers:)` | SwiftUI | `func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> some View` | iOS 14.0 | [doc](https://developer.apple.com/documentation/swiftui/view/keyboardshortcut(_:modifiers:)) |
| `View.onKeyPress(_:action:)` | SwiftUI | `func onKeyPress(_ key: KeyEquivalent, action: @escaping () -> KeyPress.Result) -> some View` | iOS 17.0 | [doc](https://developer.apple.com/documentation/swiftui/view/onkeypress(_:action:)) |
| `View.defaultFocus(_:_:priority:)` | SwiftUI | `func defaultFocus<V>(_ binding: FocusState<V>.Binding, _ value: V, priority: DefaultFocusEvaluationPriority = .automatic) -> some View where V : Hashable` | iOS 17.0 | [doc](https://developer.apple.com/documentation/swiftui/view/defaultfocus(_:_:priority:)) |
| `View.focusable(_:interactions:)`, `focused(_:equals:)` | SwiftUI | `func focusable(_ isFocusable: Bool = true, interactions: FocusInteractions) -> some View` (iOS 17.0); `func focused<Value>(_ binding: FocusState<Value>.Binding, equals value: Value) -> some View where Value : Hashable` (iOS 15.0) | iOS 15.0 and 17.0 | [doc](https://developer.apple.com/documentation/swiftui/view/focusable(_:interactions:)) |
| `AccessibilityNotification.LayoutChanged` | Accessibility | `struct LayoutChanged` with `init(_ element: Any? = nil)`; post it with `.post()` | iOS 17.0 | [doc](https://developer.apple.com/documentation/accessibility/accessibilitynotification/layoutchanged) |
| `UIAccessibility.post(notification:argument:)`, `isVoiceOverRunning` | UIKit | `static func post(notification: UIAccessibility.Notification, argument: Any?)`; `static var isVoiceOverRunning: Bool { get }` | iOS 3.0 and 4.0 | [doc](https://developer.apple.com/documentation/uikit/uiaccessibility/post(notification:argument:)) |
| `UIAccessibility.isReduceMotionEnabled`, `reduceMotionStatusDidChangeNotification` | UIKit | `static var isReduceMotionEnabled: Bool { get }`; `static let reduceMotionStatusDidChangeNotification: NSNotification.Name` | iOS 8.0 | [doc](https://developer.apple.com/documentation/uikit/uiaccessibility/isreducemotionenabled) |
| `UIAccessibility.prefersCrossFadeTransitions` | UIKit | `static var prefersCrossFadeTransitions: Bool { get }` | iOS 14.0 | [doc](https://developer.apple.com/documentation/uikit/uiaccessibility/preferscrossfadetransitions) |
| `UITraitCollection.accessibilityContrast` | UIKit | `var accessibilityContrast: UIAccessibilityContrast { get }` | iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uitraitcollection/accessibilitycontrast) |
| `UIContentSizeCategory.isAccessibilityCategory` | UIKit | `var isAccessibilityCategory: Bool { get }` | iOS 11.0 | [doc](https://developer.apple.com/documentation/uikit/uicontentsizecategory/isaccessibilitycategory) |
| `shouldGroupAccessibilityChildren`, `accessibilityContainerType`, `accessibilityUserInputLabels` | UIKit | `var shouldGroupAccessibilityChildren: Bool` (iOS 6.0); `var accessibilityContainerType: UIAccessibilityContainerType` with `.semanticGroup` (iOS 13.0); `var accessibilityUserInputLabels: [String]!` (iOS 13.0) | iOS 6.0 to 13.0 | [doc](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/shouldgroupaccessibilitychildren) |
| `UIAccessibilityCustomAction.init(name:actionHandler:)` | UIKit | `init(name: String, actionHandler: @escaping UIAccessibilityCustomAction.Handler)` | iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uiaccessibilitycustomaction/init(name:actionhandler:)) |
| `UIKeyCommand.init(title:image:action:input:modifierFlags:...)` | UIKit | `convenience init(title: String = "", image: UIImage? = nil, action: Selector, input: String, modifierFlags: UIKeyModifierFlags = [], propertyList: Any? = nil, alternates: [UICommandAlternate] = [], discoverabilityTitle: String? = nil, attributes: UIMenuElement.Attributes = [], state: UIMenuElement.State = .off)` | iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uikeycommand) |
| `UIFocusSystem.focusSystem(for:)` | UIKit | `class func focusSystem(for environment: any UIFocusEnvironment) -> UIFocusSystem?` | iOS 15.0 | [doc](https://developer.apple.com/documentation/uikit/uifocussystem) |
| `UILargeContentViewerInteraction` | UIKit | `class UILargeContentViewerInteraction : NSObject, UIInteraction` | iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uilargecontentviewerinteraction) |

- `accessibilityPrefersCrossFadeTransitions` is iOS 26.4 in SwiftUI. Gate it with `if #available(iOS 26.4, *)` when the deployment target is lower; UIKit's `prefersCrossFadeTransitions` covers iOS 14 and later.
- `focusSection()` is unavailable on iOS. See [Not in the SDK](#not-in-the-sdk).

## Animation and frame rate

Used by `duo-transitions`. Not Duo-specific.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `View.animation(_:value:)` | SwiftUI | `func animation<V>(_ animation: Animation?, value: V) -> some View where V : Equatable` | iOS 13.0 | [doc](https://developer.apple.com/documentation/swiftui/view/animation(_:value:)) |
| `View.transaction(_:)`, `transaction(value:_:)` | SwiftUI | `func transaction(_ transform: @escaping (inout Transaction) -> Void) -> some View` (iOS 13.0); `func transaction(value: some Equatable, _ transform: @escaping (inout Transaction) -> Void) -> some View` (iOS 17.0) | iOS 13.0 and 17.0 | [doc](https://developer.apple.com/documentation/swiftui/view/transaction(value:_:)) |
| `Transaction` | SwiftUI | `struct Transaction` with `var animation: Animation?`, `var disablesAnimations: Bool` | iOS 13.0 | [doc](https://developer.apple.com/documentation/swiftui/transaction) |
| `withAnimation(_:_:)`, `withTransaction(_:_:)` | SwiftUI | `func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result`; `func withTransaction<Result>(_ transaction: Transaction, _ body: () throws -> Result) rethrows -> Result` | iOS 13.0 | [doc](https://developer.apple.com/documentation/swiftui/withanimation(_:_:)) |
| `View.contentTransition(_:)` | SwiftUI | `func contentTransition(_ transition: ContentTransition) -> some View`; `ContentTransition.identity`, `.interpolate` | iOS 16.0 | [doc](https://developer.apple.com/documentation/swiftui/view/contenttransition(_:)) |
| `View.matchedGeometryEffect(id:in:properties:anchor:isSource:)` | SwiftUI | `func matchedGeometryEffect<ID>(id: ID, in namespace: Namespace.ID, properties: MatchedGeometryProperties = .frame, anchor: UnitPoint = .center, isSource: Bool = true) -> some View where ID : Hashable` | iOS 14.0 | [doc](https://developer.apple.com/documentation/swiftui/view/matchedgeometryeffect(id:in:properties:anchor:issource:)) |
| `View.geometryGroup()` | SwiftUI | `func geometryGroup() -> some View` | iOS 17.0 | [doc](https://developer.apple.com/documentation/swiftui/view/geometrygroup()) |
| `Animation.smooth` | SwiftUI | `static var smooth: Animation { get }` (also `smooth(duration:extraBounce:)`) | iOS 13.0 (inlined into the app) | [doc](https://developer.apple.com/documentation/swiftui/animation/smooth) |
| `UIContentContainer.viewWillTransition(to:with:)` | UIKit | `func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator)` | iOS 8.0 | [doc](https://developer.apple.com/documentation/uikit/uicontentcontainer/viewwilltransition(to:with:)) |
| `UIViewControllerTransitionCoordinator.animate(alongsideTransition:completion:)` | UIKit | `func animate(alongsideTransition animation: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?, completion: ((any UIViewControllerTransitionCoordinatorContext) -> Void)? = nil) -> Bool` | iOS 7.0 | [doc](https://developer.apple.com/documentation/uikit/uiviewcontrollertransitioncoordinator/animate(alongsidetransition:completion:)) |
| `UIView.animate(_:changes:completion:)` | UIKit (declared in SwiftUI) | `static func animate(_ animation: Animation, changes: () -> Void, completion: (() -> Void)? = nil)` | iOS 18.0 | [doc](https://developer.apple.com/documentation/uikit/uiview/animate(_:changes:completion:)) |
| `UIView.AnimationOptions.overrideInheritedDuration`, `UIView.inheritedAnimationDuration` | UIKit | `static var overrideInheritedDuration: UIView.AnimationOptions { get }`; `class var inheritedAnimationDuration: TimeInterval { get }` (iOS 9.0) | iOS 4.0 and 9.0 | [doc](https://developer.apple.com/documentation/uikit/uiview/animationoptions/overrideinheritedduration) |
| `CADisplayLink.preferredFrameRateRange` | QuartzCore | `var preferredFrameRateRange: CAFrameRateRange`; also `var targetTimestamp: CFTimeInterval { get }` (iOS 10.0) | iOS 15.0 | [doc](https://developer.apple.com/documentation/quartzcore/cadisplaylink/preferredframeraterange) |
| `CADisableMinimumFrameDurationOnPhone` | Info.plist key | Boolean; lets Core Animation run above 60 Hz on iPhone | iOS 15.0 | [doc](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays) |

- SwiftUI animates a resize only for views that opt in with `animation(_:value:)` or a transaction tied to the size change. `withAnimation` around a fold isn't possible: the system changes the size. `duo-transitions` explains how to opt in and out.
- The iPhone Duo simulator reports a 60 fps maximum (*measured*, [device facts](device-facts.md)). Judge 120 Hz transitions on a device.

## Scrolling

Used by the gallery app's fold transition screen and by `duo-continuity`. Not Duo-specific.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `ScrollPosition` | SwiftUI | `struct ScrollPosition : Sendable` with `init(idType: (some Hashable & Sendable).Type = Never.self)`, `mutating func scrollTo(id: some Hashable & Sendable, anchor: UnitPoint? = nil)` | iOS 18.0 | [doc](https://developer.apple.com/documentation/swiftui/scrollposition) |
| `View.scrollPosition(_:anchor:)` | SwiftUI | `func scrollPosition(_ position: Binding<ScrollPosition>, anchor: UnitPoint? = nil) -> some View` | iOS 18.0 | [doc](https://developer.apple.com/documentation/swiftui/view/scrollposition(_:anchor:)) |
| `View.onScrollTargetVisibilityChange(idType:threshold:_:)` | SwiftUI | `func onScrollTargetVisibilityChange<ID>(idType: ID.Type, threshold: Double = 0.5, _ action: @escaping ([ID]) -> Void) -> some View where ID : Hashable` | iOS 18.0 | [doc](https://developer.apple.com/documentation/swiftui/view/onscrolltargetvisibilitychange(idtype:threshold:_:)) |
| `View.onScrollPhaseChange(_:)` | SwiftUI | `func onScrollPhaseChange(_ action: @escaping (_ oldPhase: ScrollPhase, _ newPhase: ScrollPhase) -> Void) -> some View` | iOS 18.0 | [doc](https://developer.apple.com/documentation/swiftui/view/onscrollphasechange(_:)) |
| `ScrollViewReader` | SwiftUI | `struct ScrollViewReader<Content> : View where Content : View`; `ScrollViewProxy.scrollTo(_:anchor:)` | iOS 14.0 | [doc](https://developer.apple.com/documentation/swiftui/scrollviewreader) |

- Measured in the gallery (18 Oct 2026): when a text column narrows on unfold and its margins arrive late, `ScrollPosition` by ID did not keep the paragraph, and calling `scrollTo` again with the same ID did nothing. A `ScrollViewReader.scrollTo(_:anchor:)` after the width settles restored it. In a grid that only changes its column count, `ScrollPosition` by ID worked (`duo-continuity`).

## Test tools: XCUIAutomation

Used by `duo-accessibility` and the v0.2 eval oracles. These live in the Xcode 27.1 iPhone Simulator platform (`Developer/Library/Frameworks/XCUIAutomation.framework`), not in the SDK.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `XCUIDevice.voiceOverService` | XCUIAutomation | `var voiceOverService: XCUIVoiceOverService { get }` | iOS 27.0 | [doc](https://developer.apple.com/documentation/xcuiautomation/xcuidevice/voiceoverservice) |
| `XCUIVoiceOverService` | XCUIAutomation | `class XCUIVoiceOverService` with `enable()`, `disable()`, `var isEnabled: Bool`, `moveForward()`, `moveBackward()`, `currentSpeech()`, `moveIn()`, `moveOut()` (each `throws`, the moves return an `XCUIVoiceOverOutput?`) | iOS 27.0 | [doc](https://developer.apple.com/documentation/xcuiautomation/xcuivoiceoverservice) |
| `XCUIApplication.performAccessibilityAudit(for:_:)` | XCUIAutomation | `func performAccessibilityAudit(for auditTypes: XCUIAccessibilityAuditType = .all, _ issueHandler: ((XCUIAccessibilityAuditIssue) throws -> Bool)? = nil) throws` | iOS 17.0 | [doc](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/performaccessibilityaudit(for:_:)) |
| `XCUIAccessibilityAuditType` | XCUIAutomation | `struct XCUIAccessibilityAuditType : OptionSet` with `.contrast`, `.elementDetection`, `.hitRegion`, `.sufficientElementDescription`, `.dynamicType`, `.textClipped`, `.trait`, `.action`, `.parentChild`, `.all` | iOS 17.0 | [doc](https://developer.apple.com/documentation/xcuiautomation/xcuiaccessibilityaudittype) |

- *Measured* by the v0.2 evals (Xcode 27.1): `.hitRegion` did not flag 30 pt buttons; `.contrast` timed out on a low-contrast screen in the open pose; `.textClipped` reports issues with no element for text inside a `ViewThatFits` child it rejected. Don't rely on the audit alone for touch targets.

## macOS Accessibility API (duo-pose-matrix)

`duo-pose-matrix` presses Device Hub's pose buttons from a small macOS tool. These are macOS APIs in `ApplicationServices` (HIServices), checked in the macOS SDK inside Xcode 27.1.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `AXIsProcessTrustedWithOptions(_:)` | ApplicationServices (macOS) | `func AXIsProcessTrustedWithOptions(_ options: CFDictionary?) -> Bool` | macOS 10.9 | [doc](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions) |
| `kAXTrustedCheckOptionPrompt` | ApplicationServices (macOS) | `let kAXTrustedCheckOptionPrompt: Unmanaged<CFString>` | macOS 10.9 | [doc](https://developer.apple.com/documentation/applicationservices/kaxtrustedcheckoptionprompt) |
| `AXUIElementPerformAction(_:_:)` | ApplicationServices (macOS) | `func AXUIElementPerformAction(_ element: AXUIElement, _ action: CFString) -> AXError`; Device Hub's pose buttons take `kAXPressAction` | macOS 10.2 | [doc](https://developer.apple.com/documentation/applicationservices/1462091-axuielementperformaction) |

- `duo-pose` passes `kAXTrustedCheckOptionPrompt: false`, so the check never shows the permission prompt. Only the user grants Accessibility, in System Settings > Privacy & Security > Accessibility ([Apple Support](https://support.apple.com/guide/mac-help/mh43185/mac)).
- It also uses `AXUIElementCreateApplication`, `AXUIElementCopyAttributeValue` and `AXUIElementSetMessagingTimeout` from the same header (`AXUIElement.h`).

## Not in the SDK

Brief claims we could not find in the iOS 27.1 SDK:

- **`.toolbarMinimizeBehavior`**: no such modifier. The real ones are `toolbarMinimizationBehavior(_:for:)` (iOS 27.0) and `tabBarMinimizeBehavior(_:)` (iOS 26.0).
- **A "Virtual Front Camera" device type**: there is none. On iPhone Duo the existing `.builtInWideAngleCamera` and `.builtInUltraWideCamera` front devices are the virtual front camera, per Apple's camera guide.
- **"max 1080p60" for the virtual front camera**: not in the headers and not in Apple's camera guide. (unverified)
- **A posture API** (book, tabletop): no fold, posture or pose symbols exist in SwiftUI or UIKit. The hinge APIs give status and angle only.
- **A singular `reservedRegion` API**: only the plural `reservedRegions(kind:…)` exists, in both SwiftUI and UIKit.
- **`focusSection()` on iOS**: the modifier exists, but the SDK marks it `@available(iOS, unavailable)`. It is for macOS and tvOS only. Use `focusable(_:interactions:)`, `defaultFocus(_:_:priority:)` and the order of your views for keyboard focus on the inner display (`duo-accessibility`).
- **"AsyncImage HTTP caching"**: the SDK adds `AsyncImage(request:…)` initializers that take a `URLRequest`, so you can set a cache policy. We found no API that names caching. (unverified)
- **"iPhone apps resizable"**: a behaviour, not an API. No symbol to index.

## Corrections

Where the brief is wrong or incomplete:

- **`UIScreen.main` "will be deprecated"**: it is already deprecated, since iOS 26.0.
- **`AVCaptureDeviceDirectionCoordinator` is listed under AVFoundation**: it lives in **AVKit** (`AVKit/AVCaptureDeviceDirectionCoordinator.h`). Import AVKit.
- **`AVCaptureDeviceRotationCoordinator`**: that is the Objective-C name. In Swift it is `AVCaptureDevice.RotationCoordinator`. It dates from iOS 17.
- **`UIWindowSceneActivationAction`**: Objective-C name. In Swift it is `UIWindowScene.ActivationAction` (iOS 15.0).
- **`.reorderContainer(for:_:)`**: the signature is `reorderContainer(for:isEnabled:move:)`, with variants that add `in:` (several collections) and `itemID:`.
- **`.alert(_:item:)` and `.confirmationDialog(_:item:)`**: the full names are `alert(_:item:actions:)`, `alert(_:item:actions:message:)`, `confirmationDialog(_:item:titleVisibility:actions:)` and `confirmationDialog(_:item:titleVisibility:actions:message:)`.
- **`.defaultTabBarPlacement(.sidebar)` alone**: it only works on a `TabView` with `.tabViewStyle(.sidebarAdaptable)`.
- **"`.occlusion` (inner FaceTime camera; active only while camera in use)"**: incomplete. Apple's overview says the outer front camera also occludes the view, and always does.
- **"No navigation containers inside an arrangement; no arrangement inside List/ScrollView"**: the second half matches Apple's overview, which also names navigation split views. We did not find the first half in the Apple docs we read; it may come from Tech Talk 111463. (unverified)
- **Versions**: the brief gives no release for most bar and scene APIs. These arrived one release earlier, in iOS 27.0: `topBarPinnedTrailing`, `visibilityPriority(_:)`, `ToolbarOverflowMenu`, `presentationPlacement(_:)`, `UISheetPresentationController.preferredPlacement`, `UITabBarController.Sidebar.preferredPlacement`, `sceneAccessory(content:)`, `UISceneAccessory` and `defaultTabBarPlacement(_:)`. `CameraCaptureAccessory`, `cameraCapture(sceneConfiguration:)`, `toolbarVerticalBehavior(_:)`, `axisBehavior(_:)`, `toolbarVerticalEdge`, arrangements, reserved regions and the hinge are iOS 27.1.
- **`UINavigationItem.pinnedTrailingGroup` and `additionalOverflowItems`**: not new. Both date from iOS 16.0.
- **`UIBackgroundExtensionView`, `ConcentricRectangle`, `UICornerConfiguration`, `dynamicAspectRatio`, `isCameraSensorOrientationCompensationEnabled`**: not new for Duo. All date from iOS 26.0.
- **`UIRequiresFullScreen` "honoured"**: Apple's docs mark the key deprecated since iOS 26. Whether iPhone Duo still honours it is unverified.

## APIs the brief missed

Found in the SDK and added above:

- SwiftUI: `ContentMarginGuide.container` with `contentMargins(for:edges:alignment:)` and `GeometryProxy.contentMargins(for:edges:)` (asymmetric margins next to vertical bars); `toolbarVerticalCompressionBehavior(_:)`; `splitArrangementLayoutRatio`, `splitArrangementLayoutSize`, `splitArrangementFixedLayoutSize`; `splitArrangementAxis`; `overlayArrangementEdge(_:)`; `isTabViewSidebarAvailable`; `ExternalNonInteractiveAccessory`; `GeometryProxy.concentricCornerRadii`.
- UIKit: `childForPreferredVerticalBarBehavior`; `setNeedsUpdateOfVerticalBarConfiguration()`; `systemTraitsAffectingVerticalBarEdge`; `UINavigationItem.verticalBarCompressionBehavior`; `UIBarButtonItem.axisBehavior`; `UIView.LayoutRegion.bar(onEdge:extent:)`; `UITabBarController.Sidebar.isAvailable` and its delegate callback; `UIViewController.arrangementViewController`; `UISplitArrangement` and `UIOverlayArrangement` view properties; `registerSceneAccessory(_:)` and `UISceneAccessoryRegistration`; `UISceneSession.Role.windowCameraCaptureAccessory`; `UIWindowSceneDelegate.supportedInterfaceOrientations(for:)`.
- AVKit and AVFoundation: `AVCaptureDeviceDirectionMap`, `AVCaptureDeviceDescriptor`, `RotationCoordinator.videoRotationAngleRelative(toDeviceOrientation:)`.

## Behaviour claims this file does not check

The brief also makes claims about behaviour, not API names. This index does not verify them. Check each against the Tech Talks or the simulator before a skill relies on it:

- How apps built with the iOS 26, 27.0 and 27.1 SDKs look on the inner display.
- Size classes on each display, and the inner display ignoring supported orientations.
- `ArrangementView` showing only its first half on the closed phone held sideways (found while testing a two-player app on the iOS 27.1 simulator).
- `UIWindowScene.ActivationAction` hiding itself when a new window is not possible. The header only says an alternate action runs where multiple windows are not supported. *Measured* in `duo-scenes` on the simulator (19 Oct 2026): on the closed phone the action was missing with `alternate: nil` and the alternate took its place when given; on the open phone the action showed. The raw `openWindow` and `activateSceneSession` requests still succeeded on the closed phone. A real iPhone Duo is unverified.
- A division having zero width when the phone is flat.
