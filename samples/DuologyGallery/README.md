# Duology Gallery

A small SwiftUI app with one screen for each layout pattern in the [`duo-patterns`](../../plugins/duology-design/skills/duo-patterns/SKILL.md) skill, plus three screens for the v0.2 design skills: a tabletop player ([`duo-postures`](../../plugins/duology-design/skills/duo-postures/SKILL.md)), a fold transition ([`duo-transitions`](../../plugins/duology-design/skills/duo-transitions/SKILL.md) with [`duo-continuity`](../../plugins/duology/skills/duo-continuity/SKILL.md)) and design tokens ([`duo-design-system`](../../plugins/duology-design/skills/duo-design-system/SKILL.md)). Run it on the iPhone Duo simulator, then close, open and fold the phone in Device Hub to see what each screen does.

Every screen uses real sample content (an inbox, an article, a short book, a day in Lisbon, a trail map, a shop, a music library, voice memos, a nature film, a rock-pooling guide, a home energy dashboard). All names, companies and text are made up for the sample.

<p align="center">
  <img src="../../docs/assets/gallery/home-closed.png" width="260" alt="The gallery's home screen on the closed iPhone Duo: a card for each pattern with what it is for and a closed and open diagram" />
</p>

## What you need

- A Mac with Apple silicon and [Xcode 27.1](https://developer.apple.com/news/releases/) (27A9275 or later).
- The iPhone Duo simulator with iOS 27.1. It ships with Xcode 27.1.

The app targets iOS 26.0, so it also runs on older iPhones and on iPad. The Duo-only APIs sit behind `if #available(iOS 27.1, *)` (or 27.0), and each screen has a plain fallback.

## Run it

In Xcode: open `DuologyGallery.xcodeproj`, pick **iPhone Duo** as the run destination, and press Run. No signing team is needed for the simulator.

From the command line:

```bash
cd samples/DuologyGallery
export DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer

xcodebuild -project DuologyGallery.xcodeproj -scheme DuologyGallery \
  -destination 'platform=iOS Simulator,name=iPhone Duo' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build

xcrun simctl boot "iPhone Duo"   # skip if it is already booted
xcrun simctl install "iPhone Duo" build/Build/Products/Debug-iphonesimulator/DuologyGallery.app
xcrun simctl launch "iPhone Duo" dev.duology.gallery -pattern listDetail
```

`DEVELOPER_DIR` picks Xcode 27.1 for these commands only. You don't need `xcode-select`.

### Launch arguments

| Argument | What it does |
|---|---|
| `-pattern <name>` | Opens one screen straight away. Names: `listDetail`, `supportingPane`, `twoPage`, `dualView`, `extendedCanvas`, `feedReflow`, `tabsToSidebar`, `displacement`, `tabletopPlayer`, `foldTransition`, `designTokens`. |
| `-showsRegions YES` | Starts with the region overlay on: every reserved region drawn over the screen (the fold in pink, cameras and the status bar corner in orange), with their frames and the window size. The dashed-rectangle button on the home screen still turns it off. The button's choice is saved for the next launch without the argument. |
| `-select <id>` | Preselects an item: a message in list-detail, a place in dual view, a paragraph in the fold transition (which then opens at that paragraph's section). |
| `-show map` | Starts the dual view on its map when only one view fits. |

The shared scheme lists every `-pattern` argument and `-showsRegions`, turned off. Tick one in **Product > Scheme > Edit Scheme > Run > Arguments**.

### Try the poses

Device Hub sets the pose: the **Closed**, **Partially Open** and **Open** buttons under the bezel, plus the rotate buttons. Hold Option and drag the slider under the bezel for any angle. `simctl` and `devicectl` in Xcode 27.1 have no pose command ([Device Hub guide](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)).

This page calls the poses:

| Pose | In Device Hub | Display | Fold |
|---|---|---|---|
| Closed | Closed | outer, portrait | none |
| Open | Open | inner, held wide | top to bottom, inactive |
| Book | Partially Open | inner, held wide | top to bottom, active |
| Tabletop | Partially Open, then Rotate Right once | inner, held tall | side to side, active |

For each screen, check:

1. **Closed**, portrait and sideways.
2. **Open**, held wide and held tall.
3. **Book** and **tabletop**: nothing you can tap sits in the fold.
4. **Split View** on the inner display: drag the app by its home indicator to one side.
5. Fold and unfold mid-task. Selection, scroll position, page and drafts must survive.

## The screens

The behaviour below is what we saw on the iPhone Duo simulator (iOS 27.1, Xcode 27.1, light mode, 18 October 2026), in the four poses above. Screenshots of every screen in every pose are in [Screenshots](#screenshots).

| Screen | Use it for | Closed | Open and book | Tabletop | Built with |
|---|---|---|---|---|---|
| [List-detail](DuologyGallery/Patterns/ListDetailView.swift) | Mail, messages, notes, settings | An inbox: the list, then the message with Back. The column on screen uses the vertical bar: Close and the filter button on the list; Back, Reply, Flag, Archive and Delete on a message. | List and message side by side, with the message actions in the vertical bar. Open, the system picks the column widths. In book pose it evens them out, one column per side of the fold. | The message alone, with a sidebar button. With nothing selected, the list sits over the detail column, and the placeholder sits above the fold. | `NavigationSplitView(columnVisibility:preferredCompactColumn:)`, `@SceneStorage` selection |
| [Supporting pane](DuologyGallery/Patterns/SupportingPaneView.swift) | Comments, transcripts, tools, up next | An article, with a Discussion button in the vertical bar. The button is built to open the discussion in a sheet that keeps the same draft. | The discussion beside the article, narrower, and no Discussion button. In book pose the article ends at the fold. | The article alone, with the Discussion button in the top bar. In all four poses the button showed exactly when the pane was hidden. | `ArrangementView`, `.split.axes(.horizontal)`, `splitArrangementLayoutRatio` (iOS 27.1) |
| [Two-page](DuologyGallery/Patterns/TwoPageView.swift) | Books, documents, slides | A short book, one page at a time. Page buttons sit at the bottom of the vertical bar. | Two facing pages with the gap on the fold line, flat or folded. Spreads start on even pages, so pages don't swap sides when you fold. | One page above the fold and a contents list below it, so no line of text lands in the fold. | `reservedRegions(kind: .division, options: .includeInactive)` (iOS 27.1), `@SceneStorage` page |
| [Dual view](DuologyGallery/Patterns/DualView.swift) | List and map, text and preview | A day of places in Lisbon. One view at a time, with a List/Map switch in the top bar and one selection. | List leading, map trailing, one selection, no switch. | The list alone, with the List/Map switch. In all four poses the switch showed exactly when one view was hidden. | `ArrangementView` (iOS 27.1), `Map(position:selection:)`, one `@Observable` model |
| [Extended canvas](DuologyGallery/Patterns/ExtendedCanvasView.swift) | Maps, drawing, big tables | A trail map you can pan and sketch on. It fills the window, under the vertical bar too. The tool palette sits at the bottom. | The map fills the window, fold included. Open, the palette sits bottom centre. In book pose it moves into the trailing region. | The map fills the window. The palette sits in the bottom region, below the fold. | `Canvas`, reserved regions (iOS 27.1), `glassEffect` (iOS 26) |
| [Feed reflow](DuologyGallery/Patterns/FeedReflowView.swift) | Photos, shops, news | A homeware shop in two columns, picked from the grid's own width. A line above the grid says what the grid is doing. | Four columns. Open, an even count, ready to fold. In book pose two columns sit on each side and the fold is the middle gap. | Three columns. The fold runs across the grid, and rows scroll past it. | `LazyVGrid`, reserved regions with `.includeInactive`, `contentMargins(for: .container)` (iOS 27.1) |
| [Tabs to sidebar](DuologyGallery/Patterns/TabsToSidebarView.swift) | Apps with many sections | A music library with a tab bar on the side. Listen Now shows Library shortcuts. | A sidebar with a Library section. The Library shortcuts on Listen Now hide because the sidebar lists them. | No tab bar and no sidebar on screen, only a sidebar button at the top. The Library shortcuts stay hidden. | `TabView`, `.sidebarAdaptable`, `defaultTabBarPlacement(.sidebar)` and `isTabViewSidebarAvailable` (iOS 27.0) |
| [Displacement](DuologyGallery/Patterns/DisplacementView.swift) | Controls you place near the middle | Voice memos. The record group sits bottom centre over the list. | Open, the group stays bottom centre. In book pose it moves into the trailing region. The list never moves. | The group sits in the bottom region, below the fold. The list never moves. | `reservedRegions(kind: .division)` (iOS 27.1), `glassEffect` (iOS 26) |

### Screenshots

Taken with `xcrun simctl io <device> screenshot`: `--display=primary` (outer display, 1398 × 2034 px) when closed, `--display=primary-1` (inner display, 2853 × 2007 px held wide, 2007 × 2853 px held tall) when open. Scaled to half size. The status bar is set to 9:41 with `simctl status_bar`. List-detail's open, book and tabletop shots launch with `-select 1`, so they show a message.

| Screen | Closed | Open | Book | Tabletop |
|---|---|---|---|---|
| List-detail | <img src="../../docs/assets/gallery/listDetail-closed.png" width="110" alt="Inbox list on the closed phone, with Close and filter buttons in the vertical bar" /> | <img src="../../docs/assets/gallery/listDetail-open.png" width="230" alt="Open: inbox list on the left, a message on the right, message actions in the vertical bar" /> | <img src="../../docs/assets/gallery/listDetail-book.png" width="230" alt="Book pose: inbox list in the left half, the message in the right half" /> | <img src="../../docs/assets/gallery/listDetail-tabletop.png" width="110" alt="Tabletop: the message alone, with a sidebar button" /> |
| Supporting pane | <img src="../../docs/assets/gallery/supportingPane-closed.png" width="110" alt="Article on the closed phone, with Discussion and Share in the vertical bar" /> | <img src="../../docs/assets/gallery/supportingPane-open.png" width="230" alt="Open: the article with the discussion pane beside it" /> | <img src="../../docs/assets/gallery/supportingPane-book.png" width="230" alt="Book pose: the article in the left half, the discussion in the right half" /> | <img src="../../docs/assets/gallery/supportingPane-tabletop.png" width="110" alt="Tabletop: the article alone, with the Discussion button in the top bar" /> |
| Two-page | <img src="../../docs/assets/gallery/twoPage-closed.png" width="110" alt="Title page of the book on the closed phone, with page buttons at the bottom of the vertical bar" /> | <img src="../../docs/assets/gallery/twoPage-open.png" width="230" alt="Open: the title page and January as facing pages, the gap on the fold line" /> | <img src="../../docs/assets/gallery/twoPage-book.png" width="230" alt="Book pose: two facing pages, one per side of the fold" /> | <img src="../../docs/assets/gallery/twoPage-tabletop.png" width="110" alt="Tabletop: the title page above the fold, a contents list below it" /> |
| Dual view | <img src="../../docs/assets/gallery/dualView-closed.png" width="110" alt="Places list on the closed phone with the List and Map switch" /> | <img src="../../docs/assets/gallery/dualView-open.png" width="230" alt="Open: the list of places on the left, the map of Lisbon on the right" /> | <img src="../../docs/assets/gallery/dualView-book.png" width="230" alt="Book pose: the list in the left half, the map in the right half" /> | <img src="../../docs/assets/gallery/dualView-tabletop.png" width="110" alt="Tabletop: the list alone, with the List and Map switch" /> |
| Extended canvas | <img src="../../docs/assets/gallery/extendedCanvas-closed.png" width="110" alt="Trail map on the closed phone with the tool palette at the bottom" /> | <img src="../../docs/assets/gallery/extendedCanvas-open.png" width="230" alt="Open: the trail map across the whole display, the palette bottom centre" /> | <img src="../../docs/assets/gallery/extendedCanvas-book.png" width="230" alt="Book pose: the map across both halves, the palette in the right half" /> | <img src="../../docs/assets/gallery/extendedCanvas-tabletop.png" width="110" alt="Tabletop: the map across both halves, the palette below the fold" /> |
| Feed reflow | <img src="../../docs/assets/gallery/feedReflow-closed.png" width="110" alt="Shop grid in two columns on the closed phone" /> | <img src="../../docs/assets/gallery/feedReflow-open.png" width="230" alt="Open: the shop grid in four columns" /> | <img src="../../docs/assets/gallery/feedReflow-book.png" width="230" alt="Book pose: four columns, two per side, the fold as the middle gap" /> | <img src="../../docs/assets/gallery/feedReflow-tabletop.png" width="110" alt="Tabletop: the shop grid in three columns" /> |
| Tabs to sidebar | <img src="../../docs/assets/gallery/tabsToSidebar-closed.png" width="110" alt="Listen Now on the closed phone with eight tabs in a vertical tab bar" /> | <img src="../../docs/assets/gallery/tabsToSidebar-open.png" width="230" alt="Open: a sidebar with a Library section next to Listen Now" /> | <img src="../../docs/assets/gallery/tabsToSidebar-book.png" width="230" alt="Book pose: the sidebar in the left half, Listen Now in the right half" /> | <img src="../../docs/assets/gallery/tabsToSidebar-tabletop.png" width="110" alt="Tabletop: Listen Now with a sidebar button and no tab bar" /> |
| Displacement | <img src="../../docs/assets/gallery/displacement-closed.png" width="110" alt="Voice memo list on the closed phone with the record controls at the bottom" /> | <img src="../../docs/assets/gallery/displacement-open.png" width="230" alt="Open: voice memos with the record group bottom centre" /> | <img src="../../docs/assets/gallery/displacement-book.png" width="230" alt="Book pose: the record group in the right half" /> | <img src="../../docs/assets/gallery/displacement-tabletop.png" width="110" alt="Tabletop: the record group below the fold" /> |

More screenshots:

| A message, closed | The map face of the dual view, closed | Reserved regions, closed |
|---|---|---|
| <img src="../../docs/assets/gallery/listDetail-closed-message.png" width="200" alt="A message pushed on the closed phone, with Back at the top of the vertical bar and Reply, Flag, Archive and Delete below it" /> | <img src="../../docs/assets/gallery/dualView-closed-map.png" width="200" alt="Map of Lisbon with the selected place highlighted" /> | <img src="../../docs/assets/gallery/regions-closed.png" width="200" alt="Region overlay: two occlusions in the top trailing corner and a legend with their frames" /> |
| `-pattern listDetail -select 2` | `-pattern dualView -show map -select 6` | `-pattern listDetail -showsRegions YES` |

| Reserved regions, open | Reserved regions, book | Reserved regions, tabletop |
|---|---|---|
| <img src="../../docs/assets/gallery/regions-open.png" width="230" alt="Region overlay on the open phone: an inactive fold down the middle, drawn dashed" /> | <img src="../../docs/assets/gallery/regions-book.png" width="230" alt="Region overlay in book pose: an active fold down the middle" /> | <img src="../../docs/assets/gallery/regions-tabletop.png" width="110" alt="Region overlay in tabletop: an active fold across the middle" /> |
| `-pattern listDetail -showsRegions YES -select 1` | `-pattern listDetail -showsRegions YES -select 1` | `-pattern listDetail -showsRegions YES` |

## What we measured

On the iOS 27.1 iPhone Duo simulator. The table comes from the region overlay (which ignores the safe area) on 18 October 2026. The notes under it come from 16 and 18 October.

| Pose | Window | Fold (`.division`) | Occlusions |
|---|---|---|---|
| Closed | 466 × 678 pt | none | active 84 × 174 at (382, 0); active 37 × 37 at (399, 29) |
| Open | 951 × 686 pt | inactive, 40 × 669 at (455, 17) | active 84 × 124 at (867, 17); inactive 58 × 37 at (677, 38) |
| Book | 951 × 686 pt | active, 40 × 669 at (455, 17) | same as open |
| Tabletop | 669 × 951 pt | active, 669 × 40 at (0, 455) | active 144 × 82 at (525, 0); inactive 37 × 58 at (611, 677) |

- Which hardware each occlusion stands for is our reading: the status bar corner, the outer front camera (closed) and the inner front camera (open). The inner camera's region was inactive in every shot, with no camera in use.
- Held wide, the overlay reports a window 17 pt taller than the 669 pt display, and every region starts at y = 17. In the screenshots the fold band and the status bar region start at the display's top edge, so the overlay's view starts 17 pt above the display. Subtract 17 from y for display points: the fold is at (455, 0), as `duo-layout`'s probe measured in a 951 × 669 pt view. We have not found out why the overlay's view is taller. (unverified)
- The fold frame is 40 pt across in every pose, centred on the display.
- Symbol toolbar items, the tab bar and the Close button went into a vertical bar on the trailing side, under the status bar. Close sat at the top of the bar; bottom-bar items (the book's page buttons) sat at the bottom. Held tall (tabletop), there was no vertical bar: items stayed in the top bar.
- The text-only Edit button (voice memos) and the dual view's segmented List/Map switch stayed in the top bar, as the [duo-navigation bar rules](../../plugins/duology/skills/duo-navigation/references/bar-rules.md) describe.
- `contentMargins(for: .container, edges: .horizontal)` gave a 20 pt leading margin and stopped content before the vertical bar.
- Horizontal `ScrollView`s inside those margins (the shop's category chips, the music shelves) drew their content past their frame, under the status bar and the tab bar, until we added `.clipped()`.
- With column visibility left to the system (`.automatic`), list-detail launched with a selection showed the message alone in book pose, its lines running across the fold. The screen now sets the column visibility itself.

An earlier build ran every screen without a crash on an iPhone 17 Pro simulator with iOS 26.5, using the fallbacks (16 October 2026). The changes from 18 October were not run on iOS 26.5.

Not checked yet: open and held tall, Split View, right-to-left languages, dark mode on most screens, and a real iPhone Duo.

## Add screenshots of other poses

1. Boot the iPhone Duo simulator and open it in Device Hub.
2. Pick a pose with the buttons under the bezel (see [Try the poses](#try-the-poses)).
3. For each screen, launch it and save the display that is on:

```bash
xcrun simctl status_bar "iPhone Duo" override --time 9:41 --batteryState charged --batteryLevel 100
xcrun simctl launch --terminate-running-process "iPhone Duo" dev.duology.gallery -pattern twoPage
# Outer display (closed): --display=primary. Inner display (open, book, tabletop): --display=primary-1.
xcrun simctl io "iPhone Duo" screenshot --display=primary-1 twoPage-open.png
sips -Z 1427 twoPage-open.png   # half size, like the other shots
xcrun simctl status_bar "iPhone Duo" clear
```

Save them in [`docs/assets/gallery/`](../../docs/assets/gallery/) as `<screen>-<pose>.png`, with the pose one of `closed`, `open`, `book` or `tabletop`, and say the pose in the alt text.

## How the project is laid out

```text
DuologyGallery/
  App/
    DuologyGalleryApp.swift    app entry; patterns open as full-screen covers
    GalleryHome.swift          home grid, window facts, closed and open diagrams
    Pattern.swift              the eleven screens: names, one-liners, launch names
  Patterns/                    one file per screen, each with its sample data
  Shared/
    EvenSplit.swift            two halves that always show (see below)
    FoldGeometry.swift         where the fold is, from the .division region
    FoldRegionsLayout.swift    content and controls in the regions a fold makes
    DuoTokens.swift            the duo-design-system tokens and grid helper
    FeedGrid.swift             even column counts around a fold
    ReservedRegionOverlay.swift  debug overlay for every reserved region
    GalleryChrome.swift        launch arguments, Close button, avatars
  Assets.xcassets              app icon (the Duology mark) and accent colour
```

The project uses file-system synchronized groups (`objectVersion = 77`). Add a Swift file to a folder and it builds; no project edit needed. Settings: Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency on, iPhone and iPad, bundle ID `dev.duology.gallery`.

### Shared helpers

- **`EvenSplit`** puts two views side by side when it is wider than tall and stacks them otherwise, each in exactly half the space. Use it when both halves must stay on screen in every pose, such as two players or a before and after. `ArrangementView` may show only its primary view when space is tight, which is right for the other patterns but wrong there. The home screen's open diagrams use it. The same type is documented in the `duo-layout` skill.
- **`FoldGeometry`** and `onFoldChange(_:)` read the fold from `reservedRegions(kind: .division, options: .includeInactive)` on every geometry change. Ask for inactive regions too: a flat phone returns none by default. The query also returns a region that only touches the view, so `FoldGeometry` keeps a fold only when it lies inside the view (`liesInside(_:of:)`). Before iOS 27.1 the modifier does nothing.
- **`feedColumns(for:minTileWidth:spacing:)`** is a pure function, so you can test it on the Mac. We did, with a 150 pt minimum tile and 12 pt spacing: 5 columns at 867 pt with no fold, 4 with an inactive fold, and with an active 40 pt fold the column widths and gaps add up to exactly 867 pt.
- **`controlRegion(in:fold:)`** returns where controls may sit: the whole view when flat, the trailing region when folded like a book, the bottom region when folded across.
- **`FoldRegionsLayout`** is the `duo-postures` layout for two views, content first and controls second. With no active fold the controls float over the content at the bottom. Folded like a book, the content goes leading and the controls trailing; folded across, the content goes on top and the controls below. It is one `Layout` in every pose, so neither view is rebuilt. The tabletop player uses it.
- **`DuoTokens.swift`** holds the `duo-design-system` token module (`DuoSpace`, `DuoTokens`, `@DuoMetrics`, `DuoType`, `DuoCard`, `duoTouchTarget()`) and its grid helper (`DuoFold`, `DuoGridGeometry`, `DuoColumns`). The design tokens screen draws `DuoColumns` over a real screen. The skill's `duoContainerMargins()` is left out because `containerMargins(_:)` in `FeedGrid.swift` is the same code.

## Rules the screens follow

- Layout comes from size class, the view's own size and reserved regions. No `UIScreen.main`, no `userInterfaceIdiom`, no orientation checks, no hinge angle, no fixed screen sizes.
- Navigation containers sit at the root of each screen. No `ArrangementView` inside a `NavigationSplitView`, `List` or `ScrollView`.
- System toolbars, sheets and dialogs do the fold avoidance they already know how to do. Code only moves controls the app places itself.
- Scrolling content never moves out of the fold. Only controls do.

Sources for each rule: [`reference/sources.md`](../../reference/sources.md). Every API with its availability: [`reference/api-index.md`](../../reference/api-index.md).

## License

MIT, like the rest of Duology. Map tiles in the dual view come from Apple Maps through MapKit.
