# Architecture of the reader recipe

How the generated project fits together, why each piece sits where it does, and what we ran to check it. Paths use `<App>` for the app name you gave `new-project.sh`.

## The layers

```text
<App>App                          launch switches, nothing else
 └─ RootView                      owns the one LibraryStore; never changes identity
     └─ NavigationStack(path:)    the path lives in the store
         ├─ LibraryView           Continue Reading card, then the shelf
         │   └─ ShelfLayout       covers in ShelfColumns: even count, split at the fold
         └─ ReaderScreen          pushed for a Book.ID
             ├─ PageView slot 0   always there, the same view in every pose
             ├─ PageView slot 1   only in a spread
             ├─ tabletop controls only in tabletop, below the fold
             └─ toolbars          Contents, Text Size, Previous, Next (not in tabletop)
```

`<App>/Model/` sits under all of it and imports Foundation and CoreGraphics only. `<App>/Text/Paginator.swift` imports UIKit in the app and AppKit on the Mac, so the model tests run it too.

## Who owns what

| Thing | Owner | Why there |
|---|---|---|
| The place in each book (chapter and character offset) | `ReadingLog` in `LibraryStore`, saved to `UserDefaults` as JSON on every change | A fold rebuilds views below a layout change. The store sits above all of them, so the place can't be lost, and it survives quitting. |
| The navigation path | `LibraryStore.path` | The reader stays pushed through every fold and rotation. |
| `LibraryStore` | `@State` in `RootView` | `RootView` is the window's root and never changes identity. |
| Page breaks, the styled chapter, the fold, the reader's size | `@State` in `ReaderScreen` | Derived data. They are rebuilt from the place whenever the size, the text size or the chapter changes. |
| The text size step | `ReadingLog.textStep` | One setting for every book, saved with the places. |

`duo-continuity` explains the rule behind this table: state above a layout switch survives it, state below it is rebuilt. Here the only state that matters is a pair of numbers, and it lives above everything.

## One page turn, start to finish

1. The reader taps Next Page (or swipes, or VoiceOver scrolls).
2. `ReaderScreen.turn(forward:)` asks the current `PageBreaks` for `turn(forward:from:perSpread:chapter:chapterCount:)`. It answers with a `PageTurn`: `.offset(n)` (the first character of the next page or spread), `.chapter(i, atEnd:)` (the next chapter's start, or the previous chapter's end), or `.none` at either end of the book.
3. `LibraryStore.apply(_:in:)` turns that into a `ReadingPosition` and saves it. The end of a chapter is its last character, so the reader lands on its last page whatever the page size.
4. `ReaderScreen` reads the new place. A new chapter changes the pagination key, so `paginate` runs at once. In the same chapter, `firstPage` moves to the page that holds the new offset.

The views never decide where a turn goes. That keeps the rules testable without a simulator.

## Pagination

`Paginator.pageBreaks(for:pageSize:)` fills page-sized TextKit 1 containers (`NSLayoutManager`, `NSTextContainer`) until the text runs out, and records each page's character range. Each `PageView` shows `attributedSubstring(from:)` of its range in a `UITextView(usingTextLayoutManager: false)` with the same line fragment padding and no insets, so a page renders exactly what was measured. The same approach as `duo-reading`.

`ReaderScreen` paginates in `.task(id: PaginationKey)`. The key is the chapter, the page size and the Dynamic Type size:

- **New chapter or text size:** paginate at once. Old breaks never show for another chapter: until the new breaks arrive, the pages are blank (`hasPages`).
- **New page size only** (a fold, a rotation, Split View): wait 200 ms first. A fold sends many sizes in a row; `task(id:)` cancels the wait when a newer one arrives.
- **The fold turns active or inactive** with no size change (open flat to book): the key doesn't change, so nothing paginates again. The spread's page size is the same flat and folded.

## The layout

`ReaderLayout(size:fold:prefersSpread:insets:)` decides the mode and the regions. `onFoldChange` (in `Shared/FoldReader.swift`) reads the fold from `reservedRegions(kind: .division, options: .includeInactive)` inside `onGeometryChange`, on the reader's own frame, so the fold's frame is in the same space as the pages.

| Fold in the reader | Mode | Regions |
|---|---|---|
| Top to bottom, crossing the middle half, active or flat | spread | leading: up to the fold's frame; trailing: after it |
| Side to side, crossing the middle half, active | tabletop | the page above the fold; the controls below it |
| Side to side and flat, or none | single | the whole reader |
| None, regular width and wider than tall (iPad) | spread | two halves with a 32 pt gutter |

- Both pages of a spread get the narrower region's width, so one pagination serves both, and both are centred in their regions.
- `PageInsets` keeps 40 pt above the text for the running head, 36 pt below for the page number, 24 pt at each side, and lines no wider than 600 pt.
- The reader measures its size on a frame with `minWidth: 0` and `minHeight: 0`, so the page sizes can never feed back into the measured size (`duo-reading` measured that loop).
- A fold near the reader's edge (Split View beside the fold) is ignored: the reader stays one page.

## The shelf

`ShelfColumns(width:fold:minWidth:spacing:margin:)` gives the columns. Without a fold: as many 140 pt columns as fit. With a top-to-bottom fold, flat or folded: the same number on each side, all the same width, the fold's frame as the gap between the two groups. So the count is even and no cover sits on the fold, which is what `duo-design-review` rule R5 asks. `ShelfLayout` places the tiles row by row in those columns. The Continue Reading card spans only the leading group, so its button never sits on the fold.

## Model API

| Member | What it does |
|---|---|
| `Library.decode(from:)`, `book(_:)` | The bundled books. |
| `Book`, `Chapter.resource` | A book's chapters, each a `.txt` file in the bundle. |
| `ChapterText(title:body:)`, `length`, `titleRange`, `excerpt(at:words:)` | The text the reader lays out: the title, then one paragraph per line. Offsets count UTF-16 units, like `NSString`. |
| `ReadingPosition` | `chapter` and `offset`. |
| `ReadingLog.position(of:)`, `record(_:in:)`, `hasStarted(_:)`, `opened(_:)`, `forget(_:)`, `progress(_:chapterLengths:)`, `textStep` | Places, the last book, the text size step. |
| `TextSizeStep.index(system:step:count:)`, `clamped(_:system:count:)` | The text size step, kept inside the 12 Dynamic Type sizes. |
| `PageBreaks.page(containing:)`, `firstPage(showing:perSpread:)`, `shown(from:perSpread:)`, `isAtEnd(from:perSpread:)`, `turn(...)` | Which page holds the place, what's on screen, where a turn goes. |
| `PageTurn` | `.offset(n)`, `.chapter(i, atEnd:)`, `.none`. |
| `ReaderLayout`, `PageInsets` | Mode, page regions, page size, tabletop controls region. |
| `ShelfColumns` | The shelf's columns and the leading group. |
| `FoldGeometry(candidates:in:)` | Which reserved region is the fold. Same type as the media player recipe and `duo-postures`. |

Every model type is `nonisolated` and `Sendable`. The app compiles with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and so does the test program. Its last check runs in `Task.detached` and uses every model type, so a type that loses `nonisolated` stops the build. `Paginator` stays on the main actor in both.

## Launch switches and the test marker

Debug builds only (`#if DEBUG`). The last copy of a switch wins: `-open ID`, `-chapter N`, `-offset N`, `-textStep N`, `-resetState`, `-uiTesting`. The full table is in the generated project's `README.md`.

With `-uiTesting`, `ReaderScreen` adds a 1 × 1 pt accessibility element, `reader.state`, whose value is `book=keeper|chapter=0|offset=2400|first=2|pages=8|mode=spread|shown=1261-2546|step=0|ready=1|`. `shown` is the range of characters on screen; `ready=1` means the breaks match the current chapter, page size and text size. Each field ends with `|`, so a test waiting for `offset=0|` never matches `offset=0123|`. Without `-uiTesting` the element doesn't exist, so VoiceOver never meets it.

## The UI tests

| Test | Checks |
|---|---|
| `testLibraryOpensABook` | A new book shows "New"; tapping it opens chapter 1 at character 0, paginated. |
| `testLibraryRemembersWhereYouAre` | After a relaunch, Continue Reading and the tile's progress show; the reader opens at the saved chapter and offset, on screen. |
| `testNextAndPreviousPage` | Next moves the place to the new page's first character; Previous goes back to 0. |
| `testTheLastPageLeadsToTheNextChapter` | Next on the last page opens the next chapter at its start. |
| `testTheFirstPageLeadsBackToThePreviousChapter` | Previous on the first page opens the previous chapter at its last page. |
| `testContentsOpensAChapter` | The Contents menu opens a chapter at its start. |
| `testSwipeTurnsThePage` | A swipe to the left turns forward. |
| `testLargerTextKeepsThePlace` | Two steps of Larger Text: more pages, the same offset, still on screen. |
| `testReaderLayoutInThisPose` | One page, two pages side by side, or the page above the turns, by mode; every control on screen, and at least 44 pt in tabletop; saves a screenshot of each display. |

Every test that moves the place ends by checking the saved offset falls inside `shown`. That is the rule that matters in every pose: the words you were reading are on screen.

Duo simulator notes:

- Tap through `element.coordinate(withNormalizedOffset:)` (`tapCentre()`). Points worked out from the app's frame can miss the app on this simulator.
- Menu items are found by their titles (`app.buttons["Larger Text"]`).
- `XCUIScreen.main` is the outer display, black while the phone is open (*measured*). The layout test attaches one screenshot per display from `XCUIScreen.screens`.
- The tests never set the pose. Set it in Device Hub (or with `duo-pose`), then run `testReaderLayoutInThisPose` once per pose.
- `run-ui-tests.sh` passes `-parallel-testing-enabled NO` (no simulator clones) and `-collect-test-diagnostics never`.
