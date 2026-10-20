# Evidence: what we ran for duo-swiftui-27

Every *measured* claim in this skill comes from the runs below. All ran on 20 October 2026 with Xcode 27.1 (27A9275) on the shared iPhone Duo simulator (iOS 27.1). None ran on a real iPhone Duo.

## The probe

A small SwiftUI app with one screen per check, built with Xcode 27.1 at an iOS 27.1 deployment target. Each screen carried a background view that logged its size inside the safe area, its size classes, its four safe area insets and the state of the `.division` region (`none`, `inactive` or `active`, read with `reservedRegions(kind: .division, options: .includeInactive)`). So every result below names the pose the app saw, not only the pose we asked for.

- Poses were set with `duo-pose` from `duo-pose-matrix`, which presses Device Hub's buttons. "Book" is Partially Open, held wide; "tabletop" is Partially Open, then Rotate Right.
- UI checks ran as XCUITest cases. Pose walks ran while a UI test held the simulator, so other tools waited.
- Screenshots came from `xcrun simctl io <device> screenshot --display=primary` (outer) and `--display=primary-1` (inner), and from `XCUIScreen` inside the tests.

Size notation: width × height in points inside the safe area. Insets: top, leading, bottom, trailing.

## State macro

Screen: a parent `GeometryReader` with two children. One holds `@State private var model = ProbeModel()`. The other holds `private var model = State(wrappedValue: ProbeModel())`, which evaluates its initial value on every `init` (the old timing). `ProbeModel.init` counts itself.

| Step | Parent size | Child `init` runs | Macro models | Old-timing models |
|---|---|---|---|---|
| Launch, closed | 382 × 644 (compact, regular) | 1 | 1 | 1 |
| Unfold | 466 × 562, then 951 × 553, then 867 × 635 | 3 more | 1 | 4 |
| Fold | 867 × 635 compact, then 382 × 644 | 1 more | 1 | 5 |

Trap screen: two copies of a reader page built with `startPage: 42`. With `@State private var page: Int = 0` and the assignment last in `init`, the page showed 0. With no inline default, it showed 42.

Compiler checks, outside the simulator, with `swiftc` from Xcode 27.1 at an iOS 27.1 target unless noted:

| Case | `-typecheck` | `-emit-sil` |
|---|---|---|
| Inline default, `@State` assigned before another stored property | no error | `variable 'self.book' used before being initialized` |
| No default, `@State` assigned first (TN3211's example) | no error | no error (also Swift 5 and 6 modes, iOS 17.0 and 26.0 targets) |
| `@State @Clamped var counter = 0` | `property wrapper cannot be applied to a computed property` | same |
| Private memberwise `init` called from an extension | `extraneous argument label 'bar:' in call` | same |
| `.overlay(Color.blue.opacity(0.70).blendMode(.overlay))` | `ambiguous use of 'opacity'` | same |
| Constraint `Content == VStack<TupleView<(Text, Text)>>` | `cannot convert value of type 'VStack<TupleContent<Text, Text>>' ...` | same; no error at an iOS 26.0 target |
| `Group { }` with MapKit imported | `... requires that 'EmptyMapContent' conform to 'View'` | same |
| `alert(_:item:actions:)`, `confirmationDialog(_:item:...)` and `EmptyContent()` | no error at an iOS 15.0 target | |
| Collection ID enum without `nonisolated`, MainActor default isolation and `InferIsolatedConformances` | `main actor-isolated conformance of 'Lane' to 'Hashable' cannot satisfy conformance requirement for a 'Sendable' type parameter` | |

## Reorder and swipe

UI tests, one run per pose. The probe's own log confirms each pose:

| Pose | Grid screen | Board and swipe screens |
|---|---|---|
| Closed | 382 × 644, compact width, fold none | 382 wide, compact width, fold none |
| Open, held wide | 867 × 635, regular width, fold inactive | 867 wide, regular width, fold inactive |
| Book | 867 × 635, regular width, fold active | 867 wide, regular width, fold active |

| Test | Closed | Open | Book |
|---|---|---|---|
| Grid of 12 tiles: drag tile 0 onto tile 3 (1 s press, `.slow` drag, 0.5 s hold) | `move` got sources [0], `.before(4)`; order 1,2,3,0,4,... | same | same |
| Two lanes (0–4 and 10–14): drag card 1 onto card 12 | `move` got sources [1], destination trailing, `.before(12)`; leading 0,2,3,4, trailing 10,11,1,12,13,14 | same | same |
| `swipeLeft()` on row 3 of a `LazyVStack` | `onPresentationChanged(true)` once; the Delete button showed | same | same |
| Tap the revealed action | closed only: found with `label BEGINSWITH 'Delete'` (its label was "Delete, Delete"); `app.buttons["Delete"]` did not exist; the tap deleted the row (20 rows to 19) | | |

An earlier run of the same tests, before we logged the pose inside the app, reported "closed" while its screenshots showed the open inner display. We dropped those results. Log the pose in the app, not only in the script.

## Toolbars and tabs

Tab screen: `TabView` with Shop, Packs, Saved and a `.prominent` Cart. Shop holds a `NavigationStack` with a large title and a list.

| Pose | What the screenshot showed |
|---|---|
| Closed | Vertical bar on the trailing side, symbols only; Cart as a separate round button at the foot |
| Open, held wide | The same on the inner display |
| Inner display held tall (Partially Open, Rotate Right) | Horizontal bar at the bottom with titles; Cart as a separate round button at the trailing end |

Minimize screen: a `NavigationStack` with a large title, a `.primaryAction` Share button, a `.bottomBar` Add button and an 80-row `LazyVStack`. A UI test dragged row 8 up to row 1, then row 12 up to row 6.

| Setting | Pose | Top inset | Trailing inset | Screenshots |
|---|---|---|---|---|
| `.onScrollDown` | closed | 82 pt, then down in steps to 24 pt | 84 pt throughout | title gone after the scroll; Share at the top and Add at the bottom of the side column, unmoved |
| `.onScrollDown` | open, held wide | 82 to 24 pt | 84 pt | same |
| `.onScrollDown` | book | 82 to 24 pt | 84 pt | same |
| `.never` | closed | 82 pt throughout | 84 pt | |

## Dialogs

Screen: a button that sets an optional `Draft` and a `confirmationDialog(_:item:titleVisibility:actions:)`. The dialog opened at launch on the closed phone; then the script set open, then book, taking both displays after each step.

- Closed: the dialog showed as a bubble above the button, with "Delete Trip notes".
- Open: the same bubble above the button, on the inner display.
- Book: the bubble sat beside the button, on its leading side.
- This run predates the fold field in the log, so book rests on the pose tool's report and on the dialog's move.

## AsyncImage

A Python server on the Mac (`127.0.0.1`) served 64 × 64 PNGs with `Cache-Control: max-age=3600` and logged each request. Poses: closed, open, closed, open, about 20 s apart. The cache was emptied before each run.

| Screen | Cache policy | Requests per phase (launch closed, unfold, fold, unfold) | Total |
|---|---|---|---|
| `LazyVGrid`, 2 or 4 columns by size class, 24 images | `.reloadIgnoringLocalCacheData` | 12, 12, 0, 0 | 24 |
| same | `.useProtocolCachePolicy` | 12, 12, 0, 0 | 24 |
| `List` when compact, 4-column `LazyVGrid` when regular, 8 images | `.reloadIgnoringLocalCacheData` | 7, 8, 7, 8 | 30 |
| same | `.useProtocolCachePolicy` | 7, 1, 0, 0 | 8 |

After the grid run with the default policy, `Library/Caches/<bundle id>/Cache.db` in the app container listed all 24 image URLs.

## Not checked

- A real iPhone Duo, or 120 Hz during the fold.
- Reorder across two windows or two apps in Split View.
- `toolbarMinimizationRestoration(_:for:)` and `toolbarMinimizationSafeAreaAdjustment(_:for:)` on Duo.
- What minimizing does when the tab bar, not the navigation bar, holds the side column.
- Alerts (as opposed to confirmation dialogs) through a fold.
