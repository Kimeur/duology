# API index

Every iPhone Duo API that Duology skills use, checked against the iOS 27.1 SDK. From v0.2 it also lists the standard SwiftUI, UIKit, XCUIAutomation and macOS APIs that the design, accessibility, scenes and pose skills rely on, from [Liquid Glass and corners](#liquid-glass-and-corners) down. Those aren't Duo-specific; they are here so every name in a skill can be checked. From v0.3 it adds the frameworks the `duology-features` skills and the v0.3 recipes use, from [Foundation Models](#foundation-models) to [StoreKit and Charts](#storekit-and-charts).

- **Checked with:** Xcode 27.1 (27A9275), iOS 27.1 simulator SDK (build 24A94232), on 16 October 2026. The v0.2 sections were checked on 19 October 2026: each declaration against the SDK interfaces (XCUIAutomation in the iPhone Simulator platform, the macOS Accessibility API in the macOS SDK), each doc link through Apple's documentation JSON, and the SwiftUI and UIKit spellings in one scratch file that typechecks with no errors or warnings at an iOS 27.1 target. The v0.3 sections were checked on 20 October 2026 the same way: each declaration against the SDK interfaces and headers, each doc link through Apple's documentation JSON, and every spelling in scratch files that typecheck at an iOS 27.1 target. The test frameworks (XCTest, XCUIAutomation, AppIntentsTesting, StoreKitTest) were typechecked with their framework folders on the search path.
- **Where we looked:** the SwiftUI and SwiftUICore `.swiftinterface` files, the UIKit headers and `UIKit.swiftinterface`, the AVFoundation headers and the AVKit headers inside that SDK. For v0.3 also the `.swiftinterface` files of FoundationModels, AppIntents, WidgetKit, ActivityKit, StoreKit, Charts, GameController, TouchController, MediaPlayer, AVFAudio, PDFKit, PencilKit and their SwiftUI and UIKit overlays (`_AppIntents_SwiftUI`, `_StoreKit_SwiftUI` and others), the SpriteKit, MetalKit, TouchController and GameController headers, StoreKitTest in the SDK's `Developer/Library/Frameworks`, and AppIntentsTesting in the iPhone Simulator platform. Each doc link was fetched from Apple's documentation JSON and returned a page.
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
| `AVCaptureDevice.DeviceType.builtInOuterUltraWideCamera` | AVFoundation | `static let builtInOuterUltraWideCamera: AVCaptureDevice.DeviceType` | iOS 27.1; not macOS, Mac Catalyst, tvOS, visionOS | [doc](https://developer.apple.com/documentation/avfoundation/avcapturedevice/devicetype-swift.struct/builtinouterultrawidecamera) |
| `AVCaptureDevice.DeviceType.builtInInnerUltraWideCamera` | AVFoundation | `static let builtInInnerUltraWideCamera: AVCaptureDevice.DeviceType` | iOS 27.1; not macOS, Mac Catalyst, tvOS, visionOS | [doc](https://developer.apple.com/documentation/avfoundation/avcapturedevice/devicetype-swift.struct/builtininnerultrawidecamera) |
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
- Tech Talk 111465 gives the virtual front camera's limits: only what both front cameras share, at most 1080p at 60 fps, and no depth ([2:28](https://developer.apple.com/videos/play/tech-talks/111465/?time=148)). For the full inner (1080p, 60 fps) or outer (4K, 120 fps) camera, use the device types above.
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
| `View.reorderContainer(for:itemID:isEnabled:move:)` | SwiftUI | `func reorderContainer<Item, ItemID>(for item: Item.Type, itemID: KeyPath<Item, ItemID>, isEnabled: Bool = true, move: @escaping (_ difference: ReorderDifference<ItemID, ReorderableSingleCollectionIdentifier>) -> ()) -> some View where ItemID : Hashable, ItemID : Sendable` | iOS 27.0; not tvOS | [doc](https://developer.apple.com/documentation/swiftui/view/reordercontainer(for:itemid:isenabled:move:)) |
| `ReorderDifference.Destination` | SwiftUI | `struct Destination` with `collectionID` and `position`: `.before(ItemID)` or `.end` | iOS 27.0 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/reorderdifference/destination-swift.struct) |
| `ReorderableSingleCollectionIdentifier` | SwiftUI | `struct ReorderableSingleCollectionIdentifier : Hashable, Sendable` | iOS 27.0 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/reorderablesinglecollectionidentifier) |
| `ToolbarMinimizationBehavior` | SwiftUI | `struct ToolbarMinimizationBehavior : Hashable, Sendable` with `automatic`, `onScrollDown`, `onScrollUp`, `never` | iOS 27.0; the last three not on macOS, tvOS, watchOS, visionOS | [doc](https://developer.apple.com/documentation/swiftui/toolbarminimizationbehavior) |
| `View.toolbarMinimizationSafeAreaAdjustment(_:for:)` | SwiftUI | `func toolbarMinimizationSafeAreaAdjustment(_ adjustment: ToolbarMinimizationSafeAreaAdjustment, for bars: ToolbarPlacement...) -> some View`; the struct has `automatic`, `enabled`, `disabled` | iOS 27.0 (anyAppleOS); `enabled` and `disabled` iOS only | [doc](https://developer.apple.com/documentation/swiftui/view/toolbarminimizationsafeareaadjustment(_:for:)) |
| `View.toolbarMinimizationRestoration(_:for:)` | SwiftUI | `func toolbarMinimizationRestoration(_ restoration: ToolbarMinimizationRestoration, for bars: ToolbarPlacement...) -> some View`; the struct has `automatic`, `atScrollEdge` | iOS 27.0 (anyAppleOS); `atScrollEdge` iOS only | [doc](https://developer.apple.com/documentation/swiftui/view/toolbarminimizationrestoration(_:for:)) |
| `View.asyncImageURLSession(_:)` | SwiftUI | `func asyncImageURLSession(_ urlSession: URLSession) -> some View` | iOS 27.0 (anyAppleOS) | [doc](https://developer.apple.com/documentation/swiftui/view/asyncimageurlsession(_:)) |
| `TupleContent` | SwiftUICore | `@frozen struct TupleContent<each Content>` | iOS 26.0 in the SDK; see the note below | [doc](https://developer.apple.com/documentation/swiftui/tuplecontent) |
| `EmptyContent` | SwiftUICore | `typealias EmptyContent = EmptyView` | iOS 13.0 | [doc](https://developer.apple.com/documentation/swiftui/emptycontent) |

- "New in the iOS 27 SDK" means the symbol is in the iOS 27.1 SDK and absent from the iOS 26.5 SDK in Xcode 26.5 (17F42). The `alert` and `confirmationDialog` overloads are inlined into client code, so they build for iOS 15 targets. We typechecked them at an iOS 15.0 target.
- `swipeActionsContainer()` gives custom `ScrollView` or `LazyVStack` rows the one-open-row behaviour that `List` has built in.
- Apple explains the source changes that `@State` and `ContentBuilder` can cause in [TN3211](https://developer.apple.com/documentation/technotes/tn3211-resolving-swiftui-source-incompatibilities-for-state-and-contentbuilder).
- `TupleContent` is marked iOS 26.0 in the SDK, but the content builder produces it only when the deployment target is iOS 27 or later. Below that it still produces `TupleView` (TN3211; *measured* in `duo-swiftui-27` at an iOS 26.0 target). Return `some View` rather than spelling either type.
- Apple's [AsyncImage](https://developer.apple.com/documentation/swiftui/asyncimage) page says that from iOS 27 `AsyncImage` caches downloaded image data as the transport protocol allows, in a cache made with the default `URLSessionConfiguration`. Set a cache policy in the `URLRequest` you pass to `init(request:...)`, or give a view hierarchy its own session with `asyncImageURLSession(_:)`. No API names the cache itself.

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

Used by `duo-accessibility`, the v0.2 eval oracles and the UI tests of the recipes and `duo-app-intents`. XCUIAutomation, XCTest and AppIntentsTesting live in the Xcode 27.1 iPhone Simulator platform (`Developer/Library/Frameworks`), StoreKitTest in the SDK's `Developer/Library/Frameworks`. None of them is in the app SDK.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `XCUIDevice.voiceOverService` | XCUIAutomation | `var voiceOverService: XCUIVoiceOverService { get }` | iOS 27.0 | [doc](https://developer.apple.com/documentation/xcuiautomation/xcuidevice/voiceoverservice) |
| `XCUIVoiceOverService` | XCUIAutomation | `class XCUIVoiceOverService` with `enable()`, `disable()`, `var isEnabled: Bool`, `moveForward()`, `moveBackward()`, `currentSpeech()`, `moveIn()`, `moveOut()` (each `throws`; in Swift the moves and `currentSpeech()` return a non-optional `XCUIVoiceOverService.Output`, which has `utterance: String`) | iOS 27.0 | [doc](https://developer.apple.com/documentation/xcuiautomation/xcuivoiceoverservice) |
| `XCUIApplication.performAccessibilityAudit(for:_:)` | XCUIAutomation | `func performAccessibilityAudit(for auditTypes: XCUIAccessibilityAuditType = .all, _ issueHandler: ((XCUIAccessibilityAuditIssue) throws -> Bool)? = nil) throws` | iOS 17.0 | [doc](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/performaccessibilityaudit(for:_:)) |
| `XCUIAccessibilityAuditType` | XCUIAutomation | `struct XCUIAccessibilityAuditType : OptionSet` with `.contrast`, `.elementDetection`, `.hitRegion`, `.sufficientElementDescription`, `.dynamicType`, `.textClipped`, `.trait`, `.action`, `.parentChild`, `.all` | iOS 17.0 | [doc](https://developer.apple.com/documentation/xcuiautomation/xcuiaccessibilityaudittype) |
| `XCUIScreen.screens`, `XCUIScreen.main` | XCUIAutomation | `class var screens: [XCUIScreen] { get }`; `class var main: XCUIScreen { get }`; each has `func screenshot() -> XCUIScreenshot` | no version in the header | [doc](https://developer.apple.com/documentation/xcuiautomation/xcuiscreen/screens) |
| `XCTAttachment(string:)` | XCTest | `convenience init(string: String)` | no version in the header | [doc](https://developer.apple.com/documentation/xctest/xctattachment/init(string:)) |
| `SKTestSession` | StoreKitTest | `init(contentsOf fileURL: URL) throws`, `var disableDialogs: Bool`, `var askToBuyEnabled: Bool`, `func clearTransactions()`, `func resetToDefaultState()`; `func setSimulatedError<API>(_ error: API.Failure?, forAPI api: API) async throws` with `.purchase` and `SKTestFailures.Purchase.generic(_:)` (iOS 17.0) | iOS 14.0 | [doc](https://developer.apple.com/documentation/storekittest/sktestsession) |
| `IntentDefinitions` | AppIntentsTesting | `init(bundleIdentifier: String)`; `intents[_:]` and `entities[_:]`; `AppIntentDefinition.makeIntent`; `AnyAppIntent.run() async throws -> ResolvedIntentResult`; `AppEntityDefinition.viewAnnotations() async throws -> [ViewAnnotation]`, each with `isSelected` and `entity` | iOS 27.0 | [doc](https://developer.apple.com/documentation/appintentstesting/intentdefinitions) |

- *Measured* in the v0.3 recipes: on the iPhone Duo simulator `XCUIScreen.main` is the outer display, so its screenshot is black while the phone is open. `recipe-shop` found the same for `XCUIApplication.screenshot()`. Attach one screenshot per display from `XCUIScreen.screens`, as `duo-testing` does.
- `AppIntentsTesting` reported `isSelected` as `false` for every annotation in `duo-app-intents`' open run, the selected row included, although Apple's testing guide expects `true` for the item a detail screen shows. Treat that check as unverified.
- *Measured* by the v0.2 evals (Xcode 27.1): `.hitRegion` did not flag 30 pt buttons; `.contrast` timed out on a low-contrast screen in the open pose; `.textClipped` reports issues with no element for text inside a `ViewThatFits` child it rejected. Don't rely on the audit alone for touch targets.

## macOS Accessibility API (duo-pose-matrix)

`duo-pose-matrix` presses Device Hub's pose buttons from a small macOS tool. These are macOS APIs in `ApplicationServices` (HIServices), checked in the macOS SDK inside Xcode 27.1.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `AXIsProcessTrustedWithOptions(_:)` | ApplicationServices (macOS) | `func AXIsProcessTrustedWithOptions(_ options: CFDictionary?) -> Bool` | macOS 10.9 | [doc](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions) |
| `kAXTrustedCheckOptionPrompt` | ApplicationServices (macOS) | `let kAXTrustedCheckOptionPrompt: Unmanaged<CFString>` | macOS 10.9 | [doc](https://developer.apple.com/documentation/applicationservices/kaxtrustedcheckoptionprompt) |
| `AXUIElementPerformAction(_:_:)` | ApplicationServices (macOS) | `func AXUIElementPerformAction(_ element: AXUIElement, _ action: CFString) -> AXError`; Device Hub's pose buttons take `kAXPressAction` | macOS 10.2 | [doc](https://developer.apple.com/documentation/applicationservices/1462091-axuielementperformaction) |

- `duo-pose` passes `kAXTrustedCheckOptionPrompt: false`, so the check never shows the permission prompt. Only the user grants Accessibility, in System Settings > Privacy & Security > Accessibility ([Apple Support](https://support.apple.com/guide/mac-help/allow-accessibility-apps-to-access-your-mac-mh43185/mac)).
- It also uses `AXUIElementCreateApplication`, `AXUIElementCopyAttributeValue` and `AXUIElementSetMessagingTimeout` from the same header (`AXUIElement.h`).

## Foundation Models

Used by `duo-intelligence`. Checked in `FoundationModels.swiftinterface`; the `UIImage` attachment lives in `_FoundationModels_UIKit`. Not Duo-specific.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `SystemLanguageModel` | FoundationModels | `final class SystemLanguageModel : Sendable` with `static var default`, `init(useCase:guardrails:)`, `var availability: SystemLanguageModel.Availability`, `var isAvailable: Bool`; also `Observable` | iOS 26.0; not tvOS, watchOS | [doc](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel) |
| `SystemLanguageModel.Availability` | FoundationModels | `.available` or `.unavailable(UnavailableReason)`, with `.deviceNotEligible`, `.appleIntelligenceNotEnabled`, `.modelNotReady` | iOS 26.0 | [doc](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum) |
| `SystemLanguageModel.Guardrails.permissiveContentTransformations` | FoundationModels | `static let permissiveContentTransformations: SystemLanguageModel.Guardrails` | iOS 26.0 | [doc](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/guardrails) |
| `SystemLanguageModel.contextSize`, `supportsLocale(_:)` | FoundationModels | `var contextSize: Int { get }`; `func supportsLocale(_ locale: Locale = Locale.current) -> Bool`; `var supportedLanguages: Set<Locale.Language>` | iOS 26.0; `contextSize` back-deployed before iOS 26.4 | [doc](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/contextsize) |
| `SystemLanguageModel.tokenCount(for:)` | FoundationModels | `func tokenCount(for prompt: some PromptRepresentable) async throws -> Int` (also for `Instructions`) | iOS 26.4 | [doc](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/tokencount(for:)) |
| `SystemLanguageModel.variant` | FoundationModels | `var variant: SystemLanguageModel.Variant { get }`; `struct Variant : Sendable, Hashable` with `let displayName: String`, `static var core3`, `static var coreAdvanced3` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/variant-swift.struct) |
| `SystemLanguageModel.Error.assetsUnavailable(_:)` | FoundationModels | `enum Error : LocalizedError` with `case assetsUnavailable(SystemLanguageModel.Error.AssetsUnavailable)` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/error/assetsunavailable(_:)) |
| `PrivateCloudComputeLanguageModel` | FoundationModels | `final class PrivateCloudComputeLanguageModel : Sendable, LanguageModel, Observable` with `init()`, `var availability`, `var isAvailable: Bool`, `var quotaUsage: QuotaUsage` | iOS 27.0; not tvOS | [doc](https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel) |
| `PrivateCloudComputeLanguageModel.Availability` | FoundationModels | `.unavailable(UnavailableReason)` with `.deviceNotEligible`, `.systemNotReady` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel/availability-swift.enum) |
| `PrivateCloudComputeLanguageModel.QuotaUsage` | FoundationModels | `struct QuotaUsage : Sendable` with `status` (`.belowLimit(_:)`, whose value has `isApproachingLimit`, and `.limitReached`), `var isLimitReached: Bool`, `var resetDate: Date?` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel/quotausage-swift.struct) |
| `PrivateCloudComputeLanguageModel.Error` | FoundationModels | `enum Error : Error, LocalizedError` with `.networkFailure(_:)`, `.quotaLimitReached(_:)` (its value has `resetDate` and `limitIncreaseSuggestion`, whose `show()` asks for more), `.serviceUnavailable(_:)` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel/error) |
| `PrivateCloudComputeLanguageModel.contextSize`, `supportedLanguages`, `supportsLocale(_:)` | FoundationModels | `var contextSize: Int { get async throws }`, `var supportedLanguages: Set<Locale.Language> { get async throws }`, `func supportsLocale(_ locale: Locale = Locale.current) async throws -> Bool` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel/contextsize) |
| `LanguageModel`, `LanguageModelCapabilities` | FoundationModels | `protocol LanguageModel : Sendable` with `var capabilities: LanguageModelCapabilities`; `func contains(_ capability: LanguageModelCapabilities.Capability) -> Bool` with `.vision`, `.guidedGeneration`, `.reasoning`, `.toolCalling` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/languagemodelcapabilities) |
| `LanguageModelSession` | FoundationModels | `final class LanguageModelSession` with `convenience init(model: SystemLanguageModel = .default, tools: [any Tool] = [], instructions: String? = nil)`, `var transcript: Transcript`, `var isResponding: Bool`, `func prewarm(promptPrefix: Prompt? = nil)` | iOS 26.0; not tvOS | [doc](https://developer.apple.com/documentation/foundationmodels/languagemodelsession) |
| `LanguageModelSession.init(model:tools:instructions:)` for any model | FoundationModels | `convenience init(model: some LanguageModel, tools: [any Tool] = [], instructions: String? = nil)` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/init(model:tools:instructions:)) |
| `respond(to:generating:includeSchemaInPrompt:options:)`, `streamResponse(to:generating:includeSchemaInPrompt:options:)` | FoundationModels | `func respond<Content>(to prompt: String, generating type: Content.Type = Content.self, includeSchemaInPrompt: Bool = true, options: GenerationOptions = GenerationOptions()) async throws -> LanguageModelSession.Response<Content> where Content : Generable`; `streamResponse` returns a `ResponseStream<Content>` whose `Snapshot` has `content` and `rawContent` | iOS 26.0 | [doc](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/respond(to:generating:includeschemainprompt:options:)) |
| `respond(to:options:contextOptions:metadata:)` and the `streamResponse` overloads that take `contextOptions:` | FoundationModels | `func respond(to prompt: String, options: GenerationOptions = GenerationOptions(), contextOptions: ContextOptions = ContextOptions(), metadata: [String : any ConvertibleToGeneratedContent] = [:]) async throws -> LanguageModelSession.Response<String>` (also `generating:` forms) | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/respond(to:options:contextoptions:metadata:)) |
| `LanguageModelSession.usage`, `LanguageModelSession.Error` | FoundationModels | `var usage: LanguageModelSession.Usage { get }`; `enum Error : LocalizedError` with `.concurrentRequests`, `.transcriptMutationWhileResponding` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/usage-swift.property) |
| `LanguageModelError` | FoundationModels | `enum LanguageModelError : LocalizedError` with `.contextSizeExceeded`, `.rateLimited`, `.guardrailViolation`, `.refusal` (its value has `explanation`, `async throws`), `.unsupportedCapability`, `.unsupportedTranscriptContent`, `.unsupportedGenerationGuide`, `.unsupportedLanguageOrLocale`, `.timeout`, each with a value | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/languagemodelerror) |
| `@Generable`, `@Guide` | FoundationModels | `macro Generable(description: String? = nil)`; `macro Guide<T>(description: String? = nil, _ guides: GenerationGuide<T>...)` with guides such as `.count(_:)` | iOS 26.0 | [doc](https://developer.apple.com/documentation/foundationmodels/generable) |
| `GenerationOptions` | FoundationModels | `struct GenerationOptions : Sendable, Equatable` with `init(samplingMode: GenerationOptions.SamplingMode? = nil, temperature: Double? = nil, maximumResponseTokens: Int? = nil)`, `SamplingMode.greedy`; `var toolCallingMode` (iOS 27.0) | iOS 26.0 | [doc](https://developer.apple.com/documentation/foundationmodels/generationoptions) |
| `ContextOptions` | FoundationModels | `struct ContextOptions : Sendable, Equatable` with `init(includeSchemaInPrompt: Bool? = nil, reasoningLevel: ContextOptions.ReasoningLevel? = nil)`; `ReasoningLevel` has `.light`, `.moderate`, `.deep`, `.custom(String)` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/contextoptions) |
| `Tool` | FoundationModels | `protocol Tool<Arguments, Output> : Sendable` with `func call(arguments: Self.Arguments) async throws -> Self.Output` | iOS 26.0 | [doc](https://developer.apple.com/documentation/foundationmodels/tool) |
| `Attachment` | FoundationModels | `struct Attachment<Content>`; for images `init(_ cgImage: CGImage, orientation: CGImagePropertyOrientation? = nil)` (also `CIImage`, `CVPixelBuffer`), `init(imageURL: URL, orientation:)`, `func label(_ label: String) -> Attachment<Content>`; `init(_ uiImage: UIImage, orientation: UIImage.Orientation? = nil)` in `_FoundationModels_UIKit` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/attachment) |

- `LanguageModelSession.GenerationError` is deprecated in iOS 27.0. Its cases point to `LanguageModelError`, `LanguageModelSession.Error` and `SystemLanguageModel.Error`.
- `SystemLanguageModel.Adapter` is deprecated in iOS 26.4 and obsoleted in iOS 27.0.
- `SpotlightSearchTool` (`_CoreSpotlight_FoundationModels`, iOS 27.0) is a ready-made `Tool`. `duo-intelligence` names it and doesn't use it.
- *Measured* in `duo-intelligence` (iOS 27.1 simulator): every on-device request failed with `LanguageModelError` code -1 while `availability` said `.available`, and `contextSize` read 0. Judge answers on a device.

## App Intents

Used by `duo-app-intents`. Checked in `AppIntents.swiftinterface`, `_AppIntents_SwiftUI` and `_AppIntents_UIKit`. In SwiftUI, `anyAppleOS 26.0` means every Apple platform at version 26.0.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `AppEntity`, `EntityQuery`, `EntityStringQuery`, `EntityPropertyQuery` | AppIntents | `protocol AppEntity : AppValue, DisplayRepresentable, Identifiable`; `protocol EntityQuery : DynamicOptionsProvider, PersistentlyIdentifiable, Sendable`; `protocol EntityStringQuery : EntityQuery`; `protocol EntityPropertyQuery : EntityQuery` | iOS 16.0 | [doc](https://developer.apple.com/documentation/appintents/appentity) |
| `EnumerableEntityQuery`, `UniqueAppEntityQuery` | AppIntents | `protocol EnumerableEntityQuery : EntityQuery`; `protocol UniqueAppEntityQuery : EnumerableEntityQuery` | iOS 17.0 and 18.0 | [doc](https://developer.apple.com/documentation/appintents/enumerableentityquery) |
| `EntityProperty` (`@Property`), `EntityIdentifier(for:identifier:)` | AppIntents | `@propertyWrapper final class EntityProperty<Value>`; `init<Entity>(for entityType: Entity.Type, identifier: Entity.ID) where Entity : AppEntity` | iOS 16.0 | [doc](https://developer.apple.com/documentation/appintents/entityidentifier) |
| `IndexedEntity` | AppIntents | `protocol IndexedEntity : AppEntity` | iOS 18.0 | [doc](https://developer.apple.com/documentation/appintents/indexedentity) |
| `RelevantEntities`, `SyncableEntity`, `EntityCollection` | AppIntents | `struct RelevantEntities : Sendable`; `protocol SyncableEntity : AppEntity`; `EntityCollection<Entity>` | iOS 27.0 (anyAppleOS) | [doc](https://developer.apple.com/documentation/appintents/syncableentity) |
| `OpenIntent` | AppIntents | `protocol OpenIntent : SystemIntent` | iOS 16.0 | [doc](https://developer.apple.com/documentation/appintents/openintent) |
| `TargetContentProvidingIntent` | AppIntents | `protocol TargetContentProvidingIntent : AppIntent` with `var contentIdentifier: String { get }` | iOS 26.0; not macOS, watchOS | [doc](https://developer.apple.com/documentation/appintents/targetcontentprovidingintent) |
| `AppIntent.supportedModes`, `IntentModes` | AppIntents | `static var supportedModes: IntentModes { get }`; `struct IntentModes : OptionSet` with `.background`, `.foreground`, `static func foreground(_:)` taking `.immediate`, `.dynamic` or `.deferred` | iOS 26.0 (anyAppleOS) | [doc](https://developer.apple.com/documentation/appintents/intentmodes) |
| `AppIntent.allowedExecutionTargets`, `IntentExecutionTargets` | AppIntents | `static var allowedExecutionTargets: IntentExecutionTargets { get }`; `struct IntentExecutionTargets : OptionSet` with `.main`, `.appIntentsExtension`, `.widgetKitExtension` | iOS 27.0 (anyAppleOS) | [doc](https://developer.apple.com/documentation/appintents/appintent/allowedexecutiontargets) |
| `AppIntent.systemContext`, `IntentSystemContext` | AppIntents | `var systemContext: IntentSystemContext { get }`; `currentMode` and `currentMode.canContinueInForeground` (iOS 26.0), `isVoiceOnly` and `locale` (iOS 27.0) | iOS 16.0 | [doc](https://developer.apple.com/documentation/appintents/intentsystemcontext/isvoiceonly) |
| `AppIntent.continueInForeground(_:alwaysConfirm:)` | AppIntents | `func continueInForeground(_ dialog: IntentDialog? = nil, alwaysConfirm: Bool = true) async throws` | iOS 26.0 (anyAppleOS) | [doc](https://developer.apple.com/documentation/appintents/appintent/continueinforeground(_:alwaysconfirm:)) |
| `AppIntentError.Unrecoverable.notAllowed` | AppIntents | `static let notAllowed: AppIntentError` (in `enum Unrecoverable`) | iOS 18.0 | [doc](https://developer.apple.com/documentation/appintents/appintenterror) |
| `IntentDialog` | AppIntents | `struct IntentDialog : ExpressibleByStringInterpolation, Sendable` with `init(full:supporting:)` and `init(full:systemImageName:)` (iOS 17.2) | iOS 16.0 | [doc](https://developer.apple.com/documentation/appintents/intentdialog) |
| `ProvidesDialog`, `ReturnsValue`, `ShowsSnippetView` | AppIntents | `protocol ProvidesDialog : IntentResult`; `protocol ReturnsValue<Value> : IntentResult`; `protocol ShowsSnippetView : IntentResult` | iOS 16.0 | [doc](https://developer.apple.com/documentation/appintents/providesdialog) |
| `LongRunningIntent` | AppIntents | `protocol LongRunningIntent : ProgressReportingIntent` with `func performBackgroundTask<T>(options: LongRunningTaskOptions = [], operation: @escaping () async throws -> T) async throws -> T` | iOS 27.0 (anyAppleOS) | [doc](https://developer.apple.com/documentation/appintents/longrunningintent) |
| `CancellableIntent` | AppIntents | `protocol CancellableIntent : AppIntent` | iOS 26.4 (anyAppleOS) | [doc](https://developer.apple.com/documentation/appintents/cancellableintent) |
| `AppShortcutsProvider`, `AppShortcut` | AppIntents | `protocol AppShortcutsProvider : Sendable` with `static func updateAppShortcutParameters()`; `init<Intent>(intent: Intent, phrases: [AppShortcutPhrase<Intent>], shortTitle: LocalizedStringResource, systemImageName: String)` | iOS 16.0; the `shortTitle:` form iOS 17.0 | [doc](https://developer.apple.com/documentation/appintents/appshortcut) |
| `SetValueIntent` | AppIntents | `protocol SetValueIntent<ValueType> : AppIntent` | iOS 18.0 | [doc](https://developer.apple.com/documentation/appintents/setvalueintent) |
| `NSUserActivity.appEntityIdentifier` | AppIntents | `var appEntityIdentifier: EntityIdentifier? { get set }` (`AppEntityAnnotatable`) | iOS 18.2 | [doc](https://developer.apple.com/documentation/appintents/appentityannotatable) |
| `View.onAppIntentExecution(_:perform:)` | AppIntents (`_AppIntents_SwiftUI`) | `func onAppIntentExecution<I>(_ intent: I.Type = I.self, perform action: @escaping @MainActor (I) -> Void) -> some View where I : TargetContentProvidingIntent` | iOS 26.0; not macOS, watchOS | [doc](https://developer.apple.com/documentation/swiftui/view/onappintentexecution(_:perform:)) |
| `View.appEntityIdentifier(_:)`, `appEntityIdentifier(forSelectionType:identifier:)` | AppIntents (`_AppIntents_SwiftUI`) | `func appEntityIdentifier(_ identifier: EntityIdentifier?) -> some View`; `func appEntityIdentifier<I>(forSelectionType itemType: I.Type = I.self, identifier: @escaping @Sendable (I) -> EntityIdentifier?) -> some View where I : Hashable` | iOS 18.4 | [doc](https://developer.apple.com/documentation/swiftui/view/appentityidentifier(forselectiontype:identifier:)) |
| `SiriTipView` | AppIntents (`_AppIntents_SwiftUI`) | `init<Intent>(intent: Intent, isVisible: Binding<Bool>? = nil) where Intent : AppIntent` | iOS 16.0; not Mac Catalyst, macOS | [doc](https://developer.apple.com/documentation/appintents/siritipview) |
| `UISceneAppIntent`, `AppIntentSceneDelegate` | AppIntents (`_AppIntents_UIKit`) | `protocol UISceneAppIntent : TargetContentProvidingIntent` with `func performNavigation(forScene scene: UIScene)` and `var uiScene: UIScene?`; `protocol AppIntentSceneDelegate : UISceneDelegate` with `func scene(_ scene: UIScene, willPerformAppIntent appIntent: any UISceneAppIntent)` | iOS 26.0; not macOS, watchOS | [doc](https://developer.apple.com/documentation/appintents/uisceneappintent) |
| `UIScene.ConnectionOptions.appIntent` | AppIntents (`_AppIntents_UIKit`) | `var appIntent: (any UISceneAppIntent)? { get }` | iOS 26.0 | [doc](https://developer.apple.com/documentation/uikit/uiscene/connectionoptions/appintent) |
| `UIView.appEntityIdentifier`, `UICollectionViewAppIntentsDataSource` | AppIntents (`_AppIntents_UIKit`) | `var appEntityIdentifier: EntityIdentifier? { get set }`; `protocol UICollectionViewAppIntentsDataSource : AnyObject` | iOS 18.4 | [doc](https://developer.apple.com/documentation/appintents/uicollectionviewappintentsdatasource) |
| `View.handlesExternalEvents(preferring:allowing:)`, `Scene.handlesExternalEvents(matching:)` | SwiftUI | `func handlesExternalEvents(preferring: Set<String>, allowing: Set<String>) -> some View`; `func handlesExternalEvents(matching conditions: Set<String>) -> some Scene` | iOS 14.0; not tvOS, watchOS | [doc](https://developer.apple.com/documentation/swiftui/view/handlesexternalevents(preferring:allowing:)) |

- `openAppWhenRun` is deprecated in iOS 26.0: the SDK's message asks for `supportedModes`. `ForegroundContinuableIntent` is deprecated in iOS 26.0 in favour of `.foreground(.dynamic)` in `supportedModes`.
- `AppIntentsTesting` is in [Test tools](#test-tools-xcuiautomation), with the other test frameworks.

## Widgets, Live Activities and Controls

Used by `duo-system-surfaces`. Checked in `WidgetKit.swiftinterface`, `ActivityKit.swiftinterface` and SwiftUI. `duo-system-surfaces` keeps what Apple has published about the vertical Dynamic Island apart from what it couldn't check in the simulator.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `EnvironmentValues.isDynamicIslandLimitedInWidth` | WidgetKit | `var isDynamicIslandLimitedInWidth: Bool { get }` (declared in WidgetKit, not SwiftUI) | iOS 27.0; not macOS, tvOS, watchOS, visionOS | [doc](https://developer.apple.com/documentation/swiftui/environmentvalues/isdynamicislandlimitedinwidth) |
| `WidgetFamily.systemExtraLargePortrait` | WidgetKit | `case systemExtraLargePortrait` | iOS 27.0, macOS 27.0, visionOS 26.0 | [doc](https://developer.apple.com/documentation/widgetkit/widgetfamily/systemextralargeportrait) |
| `ActivityAttributes`, `Activity.request(attributes:content:pushType:)` | ActivityKit | `protocol ActivityAttributes : Decodable, Encodable`; `static func request(attributes: Attributes, content: ActivityContent<Activity<Attributes>.ContentState>, pushType: PushType? = nil) throws -> Activity<Attributes>` | iOS 16.1; `request(attributes:content:pushType:)` iOS 16.2 | [doc](https://developer.apple.com/documentation/activitykit/activityattributes) |
| `ActivityAuthorizationInfo.areActivitiesEnabled` | ActivityKit | `var areActivitiesEnabled: Bool { get }` | iOS 16.1 | [doc](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo/areactivitiesenabled) |
| `ActivityConfiguration` | WidgetKit | `struct ActivityConfiguration<Attributes> : WidgetConfiguration where Attributes : ActivityAttributes` | iOS 16.1; not Mac Catalyst, macOS | [doc](https://developer.apple.com/documentation/widgetkit/activityconfiguration) |
| `DynamicIsland`, `DynamicIslandExpandedRegion` | WidgetKit | `struct DynamicIsland` with `func widgetURL(_ url: URL?) -> DynamicIsland`; `struct DynamicIslandExpandedRegion<Content> where Content : View` | iOS 16.1 | [doc](https://developer.apple.com/documentation/widgetkit/dynamicisland) |
| `ActivityPreviewViewKind`, `#Preview(_:as:using:widget:contentStates:)` | WidgetKit | `enum ActivityPreviewViewKind : Sendable` with `.content` and `.dynamicIsland(_:)` (`.compact`, `.minimal`, `.expanded`) | iOS 16.2; the `#Preview` form iOS 17.0 | [doc](https://developer.apple.com/documentation/widgetkit/activitypreviewviewkind) |
| `View.activityBackgroundTint(_:)` | WidgetKit | `func activityBackgroundTint(_ color: Color?) -> some View` | iOS 16.0; not Mac Catalyst, macOS | [doc](https://developer.apple.com/documentation/swiftui/view/activitybackgroundtint(_:)) |
| `View.widgetURL(_:)` | WidgetKit | `func widgetURL(_ url: URL?) -> some View` | iOS 14.0; not tvOS | [doc](https://developer.apple.com/documentation/swiftui/view/widgeturl(_:)) |
| `View.containerBackground(_:for:)` | SwiftUI | `func containerBackground<S>(_ style: S, for container: ContainerBackgroundPlacement) -> some View where S : ShapeStyle` | iOS 17.0 | [doc](https://developer.apple.com/documentation/swiftui/view/containerbackground(_:for:)) |
| `EnvironmentValues.showsWidgetContainerBackground`, `WidgetConfiguration.containerBackgroundRemovable(_:)` | WidgetKit | `var showsWidgetContainerBackground: Bool { get }`; `func containerBackgroundRemovable(_ isRemovable: Bool = true) -> some WidgetConfiguration` | iOS 15.0 (inlined into the app) | [doc](https://developer.apple.com/documentation/swiftui/environmentvalues/showswidgetcontainerbackground) |
| `ControlWidget`, `StaticControlConfiguration` | SwiftUI, WidgetKit | `protocol ControlWidget` (SwiftUI); `struct StaticControlConfiguration<Content> : ControlWidgetConfiguration where Content : ControlWidgetTemplate` (WidgetKit) | iOS 18.0; not tvOS, visionOS | [doc](https://developer.apple.com/documentation/swiftui/controlwidget) |
| `ControlWidgetToggle`, `ControlWidgetButton` | WidgetKit | `init(isOn: Bool, action: Action, @ViewBuilder label: @escaping () -> Label, @ViewBuilder valueLabel: @escaping (Bool) -> ValueLabel) where Action : SetValueIntent, Action.ValueType == Bool`; `struct ControlWidgetButton<Label, ActionLabel, Action>` | iOS 18.0 | [doc](https://developer.apple.com/documentation/widgetkit/controlwidgettoggle) |
| `NSSupportsLiveActivities` | Info.plist key | Boolean. Xcode 27.1 has the build setting `INFOPLIST_KEY_NSSupportsLiveActivities` | iOS 16.1 (doc) | [doc](https://developer.apple.com/documentation/bundleresources/information-property-list/nssupportsliveactivities) |

- Xcode 27.1's build system has no `INFOPLIST_KEY_UIBackgroundModes` setting (checked in `CoreBuildSystem.xcspec`). A media app that plays in the background needs its own Info.plist file with the `UIBackgroundModes` key ([doc](https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes)).

## Capture sessions and devices

Used by `duo-camera`, on top of the [Camera](#camera) APIs above. Standard AVFoundation, checked in the iOS 27.1 SDK headers and typechecked in Swift.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `AVCaptureDevice.DiscoverySession` | AVFoundation | `init(deviceTypes: [AVCaptureDevice.DeviceType], mediaType: AVMediaType?, position: AVCaptureDevice.Position)`; `var devices: [AVCaptureDevice] { get }` | iOS 10.0 | [doc](https://developer.apple.com/documentation/avfoundation/avcapturedevice/discoverysession) |
| `.builtInWideAngleCamera`, `.builtInUltraWideCamera`, `.builtInDualWideCamera`, `.builtInTripleCamera` | AVFoundation | `static let ...: AVCaptureDevice.DeviceType` | iOS 10.0 to 13.0 | [doc](https://developer.apple.com/documentation/avfoundation/avcapturedevice/devicetype-swift.struct) |
| `AVCaptureDevice.isVirtualDevice`, `activePrimaryConstituent` | AVFoundation | `var isVirtualDevice: Bool { get }`; `var activePrimaryConstituent: AVCaptureDevice? { get }` (Objective-C `activePrimaryConstituentDevice`) | iOS 13.0 and 15.0 | [doc](https://developer.apple.com/documentation/avfoundation/avcapturedevice/isvirtualdevice) |
| `AVCaptureDevice(uniqueID:)`, `AVCaptureDeviceInput(device:)`, `lockForConfiguration()` | AVFoundation | `init?(uniqueID: String)`; `init(device: AVCaptureDevice) throws`; `func lockForConfiguration() throws`, `func unlockForConfiguration()` | iOS 4.0 | [doc](https://developer.apple.com/documentation/avfoundation/avcapturedevice/lockforconfiguration()) |
| `AVCaptureDevice.Format` | AVFoundation | `supportedDepthDataFormats`, `videoSupportedFrameRateRanges`, `supportedDynamicAspectRatios` (iOS 26.0); `AVCaptureDevice.AspectRatio` `.ratio1x1`, `.ratio4x3`, `.ratio3x4`, `.ratio16x9`, `.ratio9x16` (iOS 26.0) | iOS 7.0 | [doc](https://developer.apple.com/documentation/avfoundation/avcapturedevice/format) |
| `AVCaptureConnection` mirroring and rotation | AVFoundation | `var automaticallyAdjustsVideoMirroring: Bool`, `var isVideoMirrored: Bool`, `var isVideoMirroringSupported: Bool { get }`, `var videoRotationAngle: CGFloat`, `func isVideoRotationAngleSupported(_ videoRotationAngle: CGFloat) -> Bool` | iOS 6.0; the rotation angle iOS 17.0 | [doc](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/videorotationangle) |
| `AVCaptureVideoPreviewLayer.isDeferredStartSupported`, `isDeferredStartEnabled` | AVFoundation | `var isDeferredStartSupported: Bool { get }`, `var isDeferredStartEnabled: Bool` | iOS 26.0 | [doc](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer/isdeferredstartenabled) |
| `AVCapturePhotoOutput.isCameraSensorOrientationCompensationSupported` | AVFoundation | `var isCameraSensorOrientationCompensationSupported: Bool { get }` | iOS 26.0; not macOS, Mac Catalyst, tvOS, visionOS | [doc](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/iscamerasensororientationcompensationsupported) |
| `AVCaptureSession.wasInterruptedNotification`, `interruptionEndedNotification`, `InterruptionReason` | AVFoundation | `static let wasInterruptedNotification: NSNotification.Name`; `AVCaptureSessionInterruptionReasonKey`; reasons include `.videoDeviceNotAvailableWithMultipleForegroundApps` and `.videoDeviceNotAvailableDueToSystemPressure` (iOS 11.1) | iOS 4.0; the reason key iOS 9.0 | [doc](https://developer.apple.com/documentation/avfoundation/avcapturesession/interruptionreason) |
| `AVCaptureSession.isMultitaskingCameraAccessSupported`, `isMultitaskingCameraAccessEnabled` | AVFoundation | `var isMultitaskingCameraAccessSupported: Bool { get }`, `var isMultitaskingCameraAccessEnabled: Bool` | iOS 16.0; not Mac Catalyst | [doc](https://developer.apple.com/documentation/avfoundation/avcapturesession/ismultitaskingcameraaccessenabled) |
| `AVCaptureMultiCamSession.isMultiCamSupported` | AVFoundation | `class var isMultiCamSupported: Bool { get }` | iOS 13.0 | [doc](https://developer.apple.com/documentation/avfoundation/avcapturemulticamsession/ismulticamsupported) |

- `.builtInOuterUltraWideCamera` and `.builtInInnerUltraWideCamera` are unavailable on Mac Catalyst, so a Catalyst target needs `#if !targetEnvironment(macCatalyst)` around them.
- After you adopt the rotation coordinator, turn sensor orientation compensation off ([Tech Talk 111465, 8:37](https://developer.apple.com/videos/play/tech-talks/111465/?time=517)).

## Media playback

Used by `duo-media` and `recipe-media-player`. Checked in the AVFoundation, AVKit, MediaPlayer and AVFAudio headers of the iOS 27.1 SDK, and `_AVKit_SwiftUI` for `VideoPlayer`.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `AVPlayer` | AVFoundation | `class AVPlayer : NSObject`, main actor in Swift (`NS_SWIFT_UI_ACTOR`); `playImmediately(atRate:)`, `var defaultRate: Float` (iOS 16.0), `timeControlStatus`, `replaceCurrentItem(with:)`, `seek(to:toleranceBefore:toleranceAfter:)`, `addPeriodicTimeObserver(forInterval:queue:using:)` | iOS 4.0 | [doc](https://developer.apple.com/documentation/avfoundation/avplayer) |
| `AVPlayer.isObservationEnabled` | AVFoundation | `class var isObservationEnabled: Bool` | iOS 26.0 | [doc](https://developer.apple.com/documentation/avfoundation/avplayer/isobservationenabled) |
| `AVPlayer.disconnectedFromSystemAudio` | AVFoundation | `var disconnectedFromSystemAudio: Bool { get }`, set with `setDisconnectedFromSystemAudio(_:completionHandler:)` | iOS 27.0; not macOS, Mac Catalyst | [doc](https://developer.apple.com/documentation/avfoundation/avplayer) |
| `AVPlayerItem`, `AVPlayerLayer`, `AVQueuePlayer`, `AVPlayerLooper` | AVFoundation | `AVPlayerItem.didPlayToEndTimeNotification`, `presentationSize`, `duration`; `AVPlayerLayer.player`, `videoGravity`; `AVPlayerLooper(player:templateItem:)` | iOS 4.0; `AVPlayerLooper` iOS 10.0 | [doc](https://developer.apple.com/documentation/avfoundation/avplayerlooper) |
| `AVAsset.loadTracks(withMediaType:)` | AVFoundation | `func loadTracks(withMediaType mediaType: AVMediaType) async throws -> [AVAssetTrack]` | iOS 15.0 | [doc](https://developer.apple.com/documentation/avfoundation/avasset/loadtracks(withmediatype:completionhandler:)) |
| `VideoPlayer` | AVKit (`_AVKit_SwiftUI`) | `init(player: AVPlayer?)` | iOS 14.0 | [doc](https://developer.apple.com/documentation/avkit/videoplayer) |
| `AVPlayerViewController` Picture in Picture and Now Playing | AVKit | `var allowsPictureInPicturePlayback: Bool` (iOS 9.0), `var canStartPictureInPictureAutomaticallyFromInline: Bool` (iOS 14.2), `var updatesNowPlayingInfoCenter: Bool` (iOS 10.0; the header says the default is `true`) | iOS 8.0 | [doc](https://developer.apple.com/documentation/avkit/avplayerviewcontroller/updatesnowplayinginfocenter) |
| `AVPictureInPictureController` | AVKit | `class func isPictureInPictureSupported() -> Bool`, `init?(playerLayer: AVPlayerLayer)`, `var canStartPictureInPictureAutomaticallyFromInline: Bool` (iOS 14.2), `isPictureInPicturePossible`, `isPictureInPictureActive`, `startPictureInPicture()`, `stopPictureInPicture()`, `pictureInPictureButtonStartImage`, `pictureInPictureButtonStopImage` | iOS 9.0 | [doc](https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller) |
| `AVPictureInPictureControllerDelegate` restore | AVKit | `optional func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void)` | iOS 9.0 | [doc](https://developer.apple.com/documentation/avkit/avpictureinpicturecontrollerdelegate) |
| `AVRoutePickerView` | AVKit | `class AVRoutePickerView : UIView` with `var prioritizesVideoDevices: Bool` (iOS 13.0), `var activeTintColor: UIColor!` | iOS 11.0; not visionOS | [doc](https://developer.apple.com/documentation/avkit/avroutepickerview) |
| `MPNowPlayingSession` | MediaPlayer | `init(players: [AVPlayer])`, `var automaticallyPublishesNowPlayingInfo: Bool`, `var remoteCommandCenter: MPRemoteCommandCenter { get }`, `func becomeActiveIfPossible(completion:)` (also `async`) | iOS 16.0 | [doc](https://developer.apple.com/documentation/mediaplayer/mpnowplayingsession) |
| `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter` | MediaPlayer | `class func default() -> MPNowPlayingInfoCenter`; `class func shared() -> MPRemoteCommandCenter` with `playCommand`, `pauseCommand` and `addTarget(handler:)`; keys such as `MPMediaItemPropertyTitle` | iOS 5.0 and 7.1 | [doc](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter) |
| `AVPlayerItem.nowPlayingInfo` | MediaPlayer | `var nowPlayingInfo: [String : Any]?` | iOS 16.0 | [doc](https://developer.apple.com/documentation/avfoundation/avplayeritem/nowplayinginfo) |
| `AVAudioSession.setCategory(_:mode:options:)`, `setActive(_:options:)` | AVFAudio | `func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions = []) throws`, with `.playback` and `.moviePlayback` | iOS 10.0 | [doc](https://developer.apple.com/documentation/avfaudio/avaudiosession/setcategory(_:mode:options:)) |
| `AVAudioSession.didBecomeInactiveNotification`, `resumptionRecommendationNotification` | AVFAudio | `static let didBecomeInactiveNotification: NSNotification.Name` with `deactivationContextKey` (an `AVAudioSession.DeactivationContext`); `static let resumptionRecommendationNotification: NSNotification.Name` with `resumptionContextKey` (an `AVAudioSession.ResumptionContext` whose `recommendation` can be `.shouldResume`) | iOS 27.0; not macOS | [doc](https://developer.apple.com/documentation/avfaudio/avaudiosession) |
| `AccessibilityTraits.startsMediaSession` | SwiftUICore | `static let startsMediaSession: AccessibilityTraits` | iOS 13.0 | [doc](https://developer.apple.com/documentation/swiftui/accessibilitytraits/startsmediasession) |

- `AVAudioSession.interruptionNotification`, its type and option keys and `InterruptionOptions` (`.shouldResume`) are deprecated in iOS 27.0. The SDK points to `didBecomeInactiveNotification` and `resumptionRecommendationNotification`.
- Picture in Picture needs the audio background mode, and Apple recommends the `.playback` category ([Configuring your app for media playback](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback)).
- *Measured* in `recipe-media-player`: `isPictureInPictureSupported()` returned `false` on the iPhone Duo simulator. Check Picture in Picture on a device.

## Games

Used by `duo-games`. Checked in the SpriteKit, MetalKit, GameController, TouchController and QuartzCore headers, and in `_SpriteKit_SwiftUI` and `_GameController_SwiftUI`.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `SpriteView` | SpriteKit (`_SpriteKit_SwiftUI`) | `init(scene: SKScene, transition: SKTransition? = nil, isPaused: Bool = false, preferredFramesPerSecond: Int = 60)` (also with `options:`) | iOS 14.0 | [doc](https://developer.apple.com/documentation/spritekit/spriteview) |
| `SKScene.scaleMode`, `SKSceneScaleMode` | SpriteKit | `var scaleMode: SKSceneScaleMode`; `.fill` (the default), `.aspectFill`, `.aspectFit`, `.resizeFill` | iOS 7.0 | [doc](https://developer.apple.com/documentation/spritekit/skscenescalemode) |
| `SKScene.didChangeSize(_:)`, `didMove(to:)`, `isPaused`, `SKCameraNode` | SpriteKit | `func didChangeSize(_ oldSize: CGSize)`; `func didMove(to view: SKView)`; `var isPaused: Bool`; `class SKCameraNode : SKNode` with `setScale(_:)` | iOS 7.0; `SKCameraNode` iOS 9.0 | [doc](https://developer.apple.com/documentation/spritekit/skscene/didchangesize(_:)) |
| `MTKView`, `MTKViewDelegate` | MetalKit | `var autoResizeDrawable: Bool`, `var preferredFramesPerSecond: Int`, `var drawableSize: CGSize`; `func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)`, `func draw(in view: MTKView)` | iOS 9.0 | [doc](https://developer.apple.com/documentation/metalkit/mtkview/autoresizedrawable) |
| `CAMetalLayer.drawableSize`, `CADisplayLink.timestamp`, `targetTimestamp` | QuartzCore | `var drawableSize: CGSize`; `var timestamp: CFTimeInterval { get }`; `var targetTimestamp: CFTimeInterval { get }` (iOS 10.0) | iOS 8.0 and 3.1 | [doc](https://developer.apple.com/documentation/quartzcore/cadisplaylink/targettimestamp) |
| `GCController` | GameController | `class func controllers() -> [GCController]`, `class var current: GCController?` (iOS 14.0), `vendorName`, `productCategory`, `isAttachedToDevice`, `var playerIndex: GCControllerPlayerIndex` (`.index1`, `.index2`), `handlerQueue` | iOS 7.0 | [doc](https://developer.apple.com/documentation/gamecontroller/gccontroller/playerindex) |
| `GCControllerDidConnect`, `GCControllerDidDisconnect` | GameController | `static let GCControllerDidConnect: NSNotification.Name` (and `GCControllerDidDisconnect`) | iOS 7.0 | [doc](https://developer.apple.com/documentation/gamecontroller/gccontrollerdidconnectnotification) |
| `GCExtendedGamepad` handlers | GameController | `var valueChangedHandler`; `leftThumbstick.valueChangedHandler`; `buttonA.pressedChangedHandler`, `buttonMenu.pressedChangedHandler` | iOS 7.0; `buttonMenu` iOS 13.0 | [doc](https://developer.apple.com/documentation/gamecontroller/gcextendedgamepad) |
| `GCVirtualController` | GameController | `init(configuration: GCVirtualController.Configuration)`; `Configuration.isHidden` (iOS 17.0); `func setValue(_ value: CGFloat, forButtonElement element: String)` and `func setPosition(_ position: CGPoint, forDirectionPadElement element: String)` (iOS 17.0) | iOS 15.0; not macOS, tvOS, visionOS | [doc](https://developer.apple.com/documentation/gamecontroller/gcvirtualcontroller) |
| `GCEventInteraction` | GameController | `class GCEventInteraction : NSObject` (a `UIInteraction`) | iOS 18.0; not macOS, tvOS | [doc](https://developer.apple.com/documentation/gamecontroller/gceventinteraction) |
| `View.handlesGameControllerEvents(matching:)` | GameController (`_GameController_SwiftUI`) | `func handlesGameControllerEvents(matching types: GCUIEventTypes) -> some View` | iOS 18.0; not macOS, tvOS | [doc](https://developer.apple.com/documentation/swiftui/view/handlesgamecontrollerevents(matching:)) |
| `TCTouchController` | TouchController | `class var isSupported: Bool { get }`, `init(descriptor: TCTouchControllerDescriptor)`, `func automaticallyLayoutControls(for labels: [TCControlLabel])`, `controls`, `size`, `drawableSize`, `render(using:)`, `handleTouchBegan(at:index:)` (also `Moved`, `Ended`), `connect()` | iOS 26.0; not Mac Catalyst, visionOS | [doc](https://developer.apple.com/documentation/touchcontroller/tctouchcontroller) |
| `TCTouchControllerDescriptor`, `TCControlLabel`, `TCControlLayout` | TouchController | `init(mtkView: MTKView)`; labels such as `.leftThumbstick`, `.buttonA`, `.buttonB`; `protocol TCControlLayout` (`anchor`, `offset`); `TCGameControllerProductCategoryTouchController` | iOS 26.0 | [doc](https://developer.apple.com/documentation/touchcontroller/tccontrollayout) |
| `View.persistentSystemOverlays(_:)` | SwiftUI | `func persistentSystemOverlays(_ visibility: Visibility) -> some View` | iOS 16.0 | [doc](https://developer.apple.com/documentation/swiftui/view/persistentsystemoverlays(_:)) |
| `View.toolbarVisibility(_:for:)` with `ToolbarPlacement.statusBar` | SwiftUI | `func toolbarVisibility(_ visibility: Visibility, for bars: ToolbarPlacement...) -> some View`; `static var statusBar: ToolbarPlacement` | iOS 18.0; `.statusBar` iOS 27.0, iOS only | [doc](https://developer.apple.com/documentation/swiftui/view/toolbarvisibility(_:for:)) |
| `View.defersSystemGestures(on:)` | SwiftUI | `func defersSystemGestures(on edges: Edge.Set) -> some View` | iOS 16.0; iOS only | [doc](https://developer.apple.com/documentation/swiftui/view/deferssystemgestures(on:)) |
| `View.sensoryFeedback(_:trigger:condition:)` | SwiftUI | `func sensoryFeedback<T>(_ feedback: SensoryFeedback, trigger: T, condition: @escaping (_ oldValue: T, _ newValue: T) -> Bool) -> some View where T : Equatable` | iOS 17.0 | [doc](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:condition:)) |

- *Measured* in `duo-games`: `SpriteView(isPaused:)` set the scene's `isPaused` when it turned `true` and never cleared it, so the game stayed frozen. Pause the scene itself.
- *Measured* in `duo-games`: the iPhone Duo simulator connected its own controller, named "Gamepad" (product category MFi, not attached to the device), shortly after every launch, with no controller on the Mac.
- `View.statusBarHidden(_:)` is marked to be deprecated in the iOS 27.1 SDK (`deprecated: 100000`, "Use .toolbarVisibility(_, for: .statusBar) instead"). It builds without a warning today; `duo-games` uses the replacement on iOS 27 and falls back to `statusBarHidden()` below it, where `.statusBar` doesn't build without an `#available` check (*measured* in a recipe that targets iOS 26.0).
- *Measured* in `duo-games`: `TCTouchController.isSupported` was `false` on the simulator. Where `automaticallyLayoutControls(for:)` puts controls on iPhone Duo is unverified.

## Reading and text

Used by `duo-reading` and `recipe-reader`. Checked in the UIKit, PDFKit and PencilKit headers and the SwiftUI interfaces.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `NSTextStorage`, `NSLayoutManager`, `NSTextContainer` | UIKit | `NSLayoutManager.addTextContainer(_:)`, `glyphRange(for:)`, `characterRange(forGlyphRange:actualGlyphRange:)`; `NSTextContainer(size: CGSize)`, `var lineFragmentPadding: CGFloat` | iOS 7.0 | [doc](https://developer.apple.com/documentation/uikit/nslayoutmanager) |
| `UITextView(usingTextLayoutManager:)` | UIKit | `convenience init(usingTextLayoutManager: Bool)`; `false` gives a TextKit 1 view | iOS 16.0 | [doc](https://developer.apple.com/documentation/uikit/uitextview/init(usingtextlayoutmanager:)) |
| `UITextViewDelegate.textView(_:editMenuForTextInRanges:suggestedActions:)` | UIKit | `optional func textView(_ textView: UITextView, editMenuForTextInRanges ranges: [NSValue], suggestedActions: [UIMenuElement]) -> UIMenu?` | iOS 26.0 | [doc](https://developer.apple.com/documentation/uikit/uitextviewdelegate/textview(_:editmenufortextinranges:suggestedactions:)) |
| `UITextView.textDragInteraction`, `UIDragInteraction.isEnabledByDefault` | UIKit | `var textDragInteraction: UIDragInteraction? { get }`; `class var isEnabledByDefault: Bool { get }` | iOS 11.0 | [doc](https://developer.apple.com/documentation/uikit/uidraginteraction/isenabledbydefault) |
| `UIFontDescriptor.preferredFontDescriptor(withTextStyle:compatibleWith:)` | UIKit | `class func preferredFontDescriptor(withTextStyle style: UIFont.TextStyle, compatibleWith traitCollection: UITraitCollection?) -> UIFontDescriptor`; `withDesign(_:)`, `withSymbolicTraits(_:)` | iOS 10.0; `withDesign(_:)` iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uifontdescriptor/preferredfontdescriptor(withtextstyle:compatiblewith:)) |
| `UIContentSizeCategory(_:)` from `DynamicTypeSize` | SwiftUI | `init(_ dynamicTypeSize: DynamicTypeSize?)` | iOS 15.0; not macOS, watchOS | [doc](https://developer.apple.com/documentation/uikit/uicontentsizecategory) |
| `UIPageViewController.SpineLocation`, `pageViewController(_:spineLocationFor:)` | UIKit | `enum SpineLocation : Int` with `.none`, `.min`, `.mid`, `.max`; `optional func pageViewController(_ pageViewController: UIPageViewController, spineLocationFor orientation: UIInterfaceOrientation) -> UIPageViewController.SpineLocation` | iOS 5.0 | [doc](https://developer.apple.com/documentation/uikit/uipageviewcontrollerdelegate/pageviewcontroller(_:spinelocationfor:)) |
| `PDFView` | PDFKit | `var displayMode: PDFDisplayMode` (`.twoUp`, `.singlePageContinuous`), `var displaysAsBook: Bool`, `var autoScales: Bool`, `currentPage`, `go(to:)`, `currentSelection` | iOS 11.0 | [doc](https://developer.apple.com/documentation/pdfkit/pdfview/displaysasbook) |
| `PKCanvasView`, `PKToolPicker`, `PKDrawing.transformed(using:)` | PencilKit | `var drawingPolicy: PKCanvasViewDrawingPolicy` (`.anyInput`, iOS 14.0); `PKInkingTool`; `PKCanvasViewDelegate.canvasViewDrawingDidChange(_:)`; `func transformed(using transform: CGAffineTransform) -> PKDrawing` | iOS 13.0; `PKToolPicker()` iOS 14.0 | [doc](https://developer.apple.com/documentation/pencilkit/pkcanvasview) |
| `View.textSelection(_:)` | SwiftUI | `func textSelection<S>(_ selectability: S) -> some View where S : TextSelectability` | iOS 15.0; not tvOS, watchOS | [doc](https://developer.apple.com/documentation/swiftui/view/textselection(_:)) |
| `View.accessibilityScrollAction(_:)` | SwiftUI | `func accessibilityScrollAction(_ handler: @escaping (Edge) -> Void) -> ModifiedContent<Self, AccessibilityAttachmentModifier>` | iOS 13.0 | [doc](https://developer.apple.com/documentation/swiftui/view/accessibilityscrollaction(_:)) |
| `Layout` | SwiftUI | `protocol Layout : Animatable` with `sizeThatFits(proposal:subviews:cache:)` and `placeSubviews(in:proposal:subviews:cache:)` | iOS 16.0 | [doc](https://developer.apple.com/documentation/swiftui/layout) |

- Apple's `textSelection(_:)` page says that from iOS 27 people can select a range of text in `Text`. A selection that spans two `Text` views is unverified (`duo-reading`).

## StoreKit and Charts

Used by `recipe-shop` (StoreKit) and `recipe-finance-dashboard` (Charts). Checked in `StoreKit.swiftinterface`, `_StoreKit_SwiftUI` and `Charts.swiftinterface`.

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `Product.products(for:)` | StoreKit | `static func products<Identifiers>(for identifiers: Identifiers) async throws -> [Product] where Identifiers : Collection, Identifiers.Element == String` | iOS 15.0 | [doc](https://developer.apple.com/documentation/storekit/product/products(for:)) |
| `Product` price and subscription | StoreKit | `displayPrice: String`, `price: Decimal`, `priceFormatStyle: Decimal.FormatStyle.Currency`, `subscription: Product.SubscriptionInfo?`; `SubscriptionInfo.isEligibleForIntroOffer` (`async`), `introductoryOffer`; `SubscriptionOffer.paymentMode` (`.freeTrial`), `period` | iOS 15.0 | [doc](https://developer.apple.com/documentation/storekit/product) |
| `Product.SubscriptionPeriod.formatted(_:referenceDate:)` | StoreKit | `func formatted<S>(_ format: S, referenceDate: Date = .now) -> S.FormatOutput where S : FormatStyle, S.FormatInput == Duration` | iOS 16.0 | [doc](https://developer.apple.com/documentation/storekit/product/subscriptionperiod) |
| `Product.PurchaseResult`, `VerificationResult` | StoreKit | `enum PurchaseResult : Sendable` with `.success(VerificationResult<Transaction>)`, `.userCancelled`, `.pending` (not frozen: add `@unknown default`); `@frozen enum VerificationResult<SignedType>` with `.verified`, `.unverified` | iOS 15.0 | [doc](https://developer.apple.com/documentation/storekit/product/purchaseresult) |
| `Transaction.updates`, `Transaction.currentEntitlements` | StoreKit | `static var updates: Transaction.Transactions { get }`; `static var currentEntitlements: Transaction.Transactions { get }`; `func finish() async`; `let revocationDate: Date?` | iOS 15.0 | [doc](https://developer.apple.com/documentation/storekit/transaction/updates) |
| `AppStore.sync()` | StoreKit | `static func sync() async throws` | iOS 15.0 | [doc](https://developer.apple.com/documentation/storekit/appstore/sync()) |
| `StoreKitError.invalidPresentationContext` | StoreKit | `case invalidPresentationContext` | iOS 27.0 | [doc](https://developer.apple.com/documentation/storekit/storekiterror) |
| `PurchaseAction`, `EnvironmentValues.purchase` | StoreKit (`_StoreKit_SwiftUI`) | `struct PurchaseAction`; `@Environment(\.purchase)` | iOS 17.0 | [doc](https://developer.apple.com/documentation/storekit/purchaseaction) |
| `View.manageSubscriptionsSheet(isPresented:)` | StoreKit (`_StoreKit_SwiftUI`) | `func manageSubscriptionsSheet(isPresented: Binding<Bool>) -> some View` | iOS 15.0; not macOS, tvOS, watchOS | [doc](https://developer.apple.com/documentation/swiftui/view/managesubscriptionssheet(ispresented:)) |
| Marks: `AreaMark`, `LineMark`, `PointMark`, `BarMark`, `RuleMark` | Charts | `struct AreaMark` and the others, with `interpolationMethod(_:)`, `lineStyle(_:)`, `symbolSize(_:)`, `cornerRadius(_:)` | iOS 16.0 | [doc](https://developer.apple.com/documentation/charts) |
| Scales, axes and legend | Charts | `chartXScale(domain:)`, `chartYScale(domain:)`, `chartXAxis(content:)`, `chartYAxis(_:)`, `AxisMarks`, `AxisGridLine`, `AxisValueLabel`, `chartLegend(_:)` | iOS 16.0 | [doc](https://developer.apple.com/documentation/charts/customizing-axes-in-swift-charts) |

- `recipe-shop`'s scheme names its StoreKit file in a `StoreKitConfigurationFileReference` element inside `LaunchAction`. That is Xcode scheme XML, not an SDK API ([Setting up StoreKit Testing in Xcode](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)).
- *Measured* in `recipe-shop`: launched with `simctl` before any StoreKit test session, the app got no products and every price read "–". After Xcode's Run or a UI test run opened a session, prices showed.

## Migrating an existing app

Used by `duo-migrate`. Checked on 23 Oct 2026 in the UIKit headers and the SwiftUI interfaces of the iOS 27.1 SDK; the deprecations are the SDK's own messages. Apple's rule that UIKit apps built with the latest SDK need the scene life cycle from iOS 27: [Transitioning to the UIKit scene-based life cycle](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle).

| API | Framework | Declaration | Availability | Apple doc |
|---|---|---|---|---|
| `UIWindow.init(windowScene:)` | UIKit | `init(windowScene: UIWindowScene)` | iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uiwindow/init(windowscene:)) |
| `UIWindow.init(frame:)` | UIKit | `init(frame: CGRect)` | iOS 2.0, **deprecated in iOS 26.0** ("Use init(windowScene:) instead.") | [doc](https://developer.apple.com/documentation/uikit/uiwindow/init(frame:)) |
| `UIApplicationDelegate.application(_:configurationForConnecting:options:)` | UIKit | `func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration` | iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:configurationforconnecting:options:)) |
| `UISceneDelegate.scene(_:willConnectTo:options:)` | UIKit | `func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions)` | iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uiscenedelegate/scene(_:willconnectto:options:)) |
| `sceneDidBecomeActive(_:)`, `sceneWillResignActive(_:)`, `sceneWillEnterForeground(_:)`, `sceneDidEnterBackground(_:)` | UIKit (`UISceneDelegate`) | `func sceneDidBecomeActive(_ scene: UIScene)`, and the same shape for the others | iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uiscenedelegate/scenedidbecomeactive(_:)) |
| `UIApplication.willEnterForegroundNotification` | UIKit | `static let willEnterForegroundNotification: NSNotification.Name` | iOS 4.0 | [doc](https://developer.apple.com/documentation/uikit/uiapplication/willenterforegroundnotification) |
| `UIWindowScene.screen` | UIKit | `var screen: UIScreen { get }` | iOS 13.0 | [doc](https://developer.apple.com/documentation/uikit/uiwindowscene/screen) |
| `UITraitCollection.horizontalSizeClass` | UIKit | `var horizontalSizeClass: UIUserInterfaceSizeClass { get }` | iOS 8.0 | [doc](https://developer.apple.com/documentation/uikit/uitraitcollection/horizontalsizeclass) |
| `registerForTraitChanges(_:handler:)`, `UITraitHorizontalSizeClass` | UIKit (`UITraitChangeObservable`) | `func registerForTraitChanges<Self>(_ traits: [UITrait], handler: @escaping (Self, UITraitCollection) -> Void) -> any UITraitChangeRegistration` | iOS 17.0 | [doc](https://developer.apple.com/documentation/uikit/uitraitchangeobservable) |
| `traitCollectionDidChange(_:)` | UIKit | `func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)` | iOS 8.0, **deprecated in iOS 17.0** (use the trait change registration APIs) | [doc](https://developer.apple.com/documentation/uikit/uitraitenvironment/traitcollectiondidchange(_:)) |
| `UIViewController.viewWillLayoutSubviews()` | UIKit | `func viewWillLayoutSubviews()` | iOS 5.0 | [doc](https://developer.apple.com/documentation/uikit/uiviewcontroller/viewwilllayoutsubviews()) |
| `UICollectionViewFlowLayout.itemSize` | UIKit | `var itemSize: CGSize` | iOS 6.0 | [doc](https://developer.apple.com/documentation/uikit/uicollectionviewflowlayout/itemsize) |
| `UIView.ContentMode.scaleAspectFill`, `.scaleAspectFit` | UIKit | `case scaleAspectFill`, `case scaleAspectFit` | iOS 2.0 | [doc](https://developer.apple.com/documentation/uikit/uiview/contentmode-swift.enum) |
| `GeometryReader` | SwiftUI | `struct GeometryReader<Content> where Content : View` | iOS 13.0 | [doc](https://developer.apple.com/documentation/swiftui/geometryreader) |
| `View.aspectRatio(_:contentMode:)` | SwiftUI | `func aspectRatio(_ aspectRatio: CGFloat? = nil, contentMode: ContentMode) -> some View` | iOS 13.0 | [doc](https://developer.apple.com/documentation/swiftui/view/aspectratio(_:contentmode:)) |
| `EnvironmentValues.horizontalSizeClass` | SwiftUI | `var horizontalSizeClass: UserInterfaceSizeClass?` | iOS 13.0 | [doc](https://developer.apple.com/documentation/swiftui/environmentvalues/horizontalsizeclass) |
| `UIApplicationSceneManifest`, `UIApplicationSupportsMultipleScenes`, `UISceneConfigurations`, `UISceneDelegateClassName` | Info.plist keys | A dictionary in the Info.plist; `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES` asks Xcode to generate it | iOS 13.0 | [doc](https://developer.apple.com/documentation/bundleresources/information-property-list/uiapplicationscenemanifest) |

- *Measured* in `duo-migrate`: a UIKit app with no scene life cycle, built with Xcode 27.1, crashed 3.8 s after launch on the iPhone Duo simulator (`EXC_BREAKPOINT` in UIKit's check for apps that haven't adopted scenes); with a scene delegate it ran.
- *Measured* in `duo-migrate`: Xcode 27.1 reports `UIScreen.main` and `UIWindow(frame:)` as deprecated only when the deployment target is iOS 26 or later; with an iOS 16.0 target the same code typechecks without a warning.

## Not in the SDK

Brief claims we could not find in the iOS 27.1 SDK:

- **`.toolbarMinimizeBehavior`**: no such modifier. The real ones are `toolbarMinimizationBehavior(_:for:)` (iOS 27.0) and `tabBarMinimizeBehavior(_:)` (iOS 26.0).
- **A "Virtual Front Camera" device type**: there is none. On iPhone Duo the existing `.builtInWideAngleCamera` and `.builtInUltraWideCamera` front devices are the virtual front camera, per Apple's camera guide.
- **A posture API** (book, tabletop): no fold, posture or pose symbols exist in SwiftUI or UIKit. The hinge APIs give status and angle only.
- **A singular `reservedRegion` API**: only the plural `reservedRegions(kind:…)` exists, in both SwiftUI and UIKit.
- **`focusSection()` on iOS**: the modifier exists, but the SDK marks it `@available(iOS, unavailable)`. It is for macOS and tvOS only. Use `focusable(_:interactions:)`, `defaultFocus(_:_:priority:)` and the order of your views for keyboard focus on the inner display (`duo-accessibility`).
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
- **"max 1080p60" for the virtual front camera**: v0.1 listed it as unverified. Tech Talk 111465 states it, with no depth (see [Camera](#camera)).
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
- `UIWindowScene.ActivationAction` hiding itself when a new window is not possible. The header only says an alternate action runs where multiple windows are not supported. *Measured* in `duo-scenes` on the simulator (18 Oct 2026): on the closed phone the action was missing with `alternate: nil` and the alternate took its place when given; on the open phone the action showed. The raw `openWindow` and `activateSceneSession` requests still succeeded on the closed phone. A real iPhone Duo is unverified.
- A division having zero width when the phone is flat.
