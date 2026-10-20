# Architecture of the finance dashboard recipe

How the generated project fits together, why each piece is where it is, and what we ran to check it. Paths use `<App>` for the app name you gave `new-project.sh`.

## The layers

```text
RootView                         owns FinanceModel (survives every layout change); reads the width class
 └─ NavigationStack(path:)       path computed from the selection: pushed when closed, empty when open
     ├─ DashboardScreen          measures its width and fold, builds PaneFrames
     │   └─ FoldPanes            one pane at full width, or two panes split on the fold
     │       ├─ leading pane     OverviewColumn: BalanceCard, (closed: SpendingCard), ActivitySection, (closed: CategoryGrid)
     │       └─ trailing pane    SpendingColumn (SpendingCard, CategoryGrid), or TransactionDetail
     └─ TransactionScreen        closed only: TransactionDetail, pushed
```

The model (`<App>/Model/`) sits under all of it and imports only Foundation.

## One tap, start to finish

1. A row in the activity list sets `model.selection = id`.
2. Open (`isTwoPane`), `FinanceModel.path` stays empty. `DashboardScreen` sees `selectedTransaction` and puts `TransactionDetail` in the trailing pane, with `.id(transaction.id)` so a new pick starts at the top. The row stays highlighted and gets the `isSelected` trait.
3. Closed, `path` returns `[id]`, and the stack pushes `TransactionScreen`.
4. The back button sets the path to `[]`, and the setter clears the selection. The close button in the trailing pane clears it directly.
5. Changing the category calls `Ledger.setCategory(_:for:)`. Every view reads the ledger from the model, so the list, the totals and the categories update together, in either pose.

The views never work out a total. That keeps the numbers testable without a simulator.

## The panes

`DashboardScreen` measures itself inside the container margins with `onPaneGeometryChange`, which keeps only the width and the fold's x values (`PaneGeometry`), so scrolling never triggers a new layout. Then:

1. `DuoFold(proxy)` asks for `reservedRegions(kind: .division, options: .includeInactive)` on iOS 27.1. It keeps a fold that runs top to bottom through the view. A fold that runs across (the phone held tall) or only touches the view's edge (a Split View window that ends at the fold) gives nil.
2. `PaneFrames(width:count:gutter:fold:)` builds an even grid (`DuoColumns`, 8 columns on the inner display) and groups it into two halves. Flat, the gap between them is one gutter centred on the fold line; partly folded, it is the fold's frame. A fold too close to one edge puts both panes on the wider side.
3. `FoldPanes` sizes the panes from those frames and gives them compact width, so the tokens inside lay out for a half: 4 columns, tiles 2 per row.

Numbers from duo-design-system's worked example, all checked in `Tools/ModelTests/main.swift`: an 847 pt grid with the fold's frame at 435 to 475.

| | Leading pane | Gap | Trailing pane |
|---|---|---|---|
| No fold (held tall, an iPad) | 0 to 415.5 | 16 | 431.5 to 847 |
| Flat | 0 to 447 | 16, centred on 455 | 463 to 847 |
| Partly folded | 0 to 435 | 40, the fold | 475 to 847 |

Folding moves each pane edge 12 pt or less and keeps the outer margins. That is the small adjustment Apple asks for ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions)).

*Measured* by `testLayoutInThisPose` on the simulator, in window points (the grid starts at the 20 pt margin): flat, the leading pane runs from 20 to 467.7 and the trailing pane starts at 483.7; partly folded, the leading pane ends at 455.7 and the trailing pane starts at 495.7, the fold's frame.

Why not `NavigationSplitView`: its columns are sized by the system (`duo-patterns` measured 50/50 at the fold only while partly folded), and a dashboard wants its trailing pane to hold the chart until something is picked. If your screen is a plain list and detail, use `NavigationSplitView` instead.

## Unfolding on a pushed screen

The stack's path depends on the width class, so opening the phone on a pushed transaction pops it. *Measured* on the iPhone Duo simulator (iOS 27.1, 20 Oct 2026), in this recipe and in `recipe-shop`, which share the pattern:

- Popped at once, during the unfold animation, the dashboard came back with stale geometry: inside its margins it started at x = −2 pt and was 911 pt wide, with a right safe-area inset of 42 pt instead of 84 pt and no leading margin. The close button ended up under the vertical bar. It stayed so: 10 seconds later, nothing had changed. Rebuilding the dashboard with a new `.id` did not help, and turning animations on made no difference.
- A fresh launch on the open phone, and an unfold with nothing pushed, both gave x = 20 pt, 847 pt wide, right inset 84 pt.
- Switching `isTwoPane` 600 ms after the width class changes, so the pop happens after the animation, gave the same layout as a fresh launch.

So `RootView` waits 600 ms before it switches to two panes, but only when the phone opens on a pushed transaction. At launch, and when nothing is pushed, it switches at once. During the wait, the pushed transaction shows full width on the inner display. The wait is a measured workaround, not an Apple rule: check it on a device (unverified there), and drop it if a later iOS lays the dashboard out right without it.

## Model API

| Member | What it does |
|---|---|
| `Money` | Whole cents; `+`, `-`, `sum()`, `magnitude`, `fraction(of:)`, `scaled(by:)`, `decimal` for formatting, `doubleValue` for chart axes only. |
| `Ledger.balance`, `account(_:)`, `transaction(_:)` | Lookups. A credit card's negative balance counts against the total. |
| `month(containing:)`, `monthToDate(_:)` | Half-open periods: a payment at midnight on the 1st belongs to one month. |
| `spent(in:kinds:)`, `received(in:)`, `summary(now:)` | Totals. Refunds lower spending; transfers never count. |
| `categoryTotals(in:)` | Spending per category, largest first; shares add up to one. |
| `budgetPace(now:)`, `dailySpending(now:)` | Everyday spending against an even pace to the budget, and the chart's points. |
| `sections(matching:now:)` | Activity grouped by day (today, yesterday, dates), optionally one category. |
| `merchantHistory(for:months:now:)` | What a merchant cost in each recent month, oldest first. |
| `setCategory(_:for:)` | Moves a transaction to another category. |
| `DuoColumns`, `PaneFrames`, `DuoFold` | The grid and pane math above. |

Every type is `nonisolated` and `Sendable`. The app target compiles with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so without `nonisolated` the model would be main-actor code. The test build uses the same setting and runs one check in `Task.detached` that calls a method, a computed property or `==` on every model type. *Measured:* removing `nonisolated` from any one of the 15 types stops the build.

## Launch switches

Debug builds only (`#if DEBUG`). The last copy of a switch wins.

| Switch | Effect |
|---|---|
| `-uiTesting` | Animations off. |
| `-select N` | Open transaction N. The sample's ids start at 1 with 20 October's entries. |
| `-filter NAME` | One category in the activity list, for example `-filter dining`. |

## The UI tests

| Test | Checks |
|---|---|
| `testOverviewShowsBalanceAndRecentSpending` | The sample balance, the spending card, money out and the newest transaction show. |
| `testPickingATransactionShowsItsDetail` | A row opens its detail with the merchant history; open, the row stays selected; closing brings the chart back. |
| `testLaunchSelectionOpensTheDetail` | `-select` opens the right transaction with its amount. |
| `testChangingTheCategoryMovesTheTransaction` | The category menu works, and the list shows the new category after closing the detail. |
| `testFilterShowsOneCategory` | `-filter dining` keeps eating out, hides groceries, and the clear button brings everything back. |
| `testLayoutInThisPose` | Balance in the leading pane; open, the gap between panes is a gutter or the fold (12 to 60 pt), the detail opens in the trailing pane, the close button is at least 44 pt. Attaches the pane frames and a screenshot of each display. |

Duo simulator notes (*measured*):

- Closed, the back button is in the vertical bar, which XCUITest reports as a toolbar, not a navigation bar. `app.buttons["BackButton"]` finds it.
- `LabeledContent` wrapping a menu picker made one accessibility element as wide as the row, and a tap on its centre missed the picker; an `HStack` with the picker on its own fixed it.
- A coordinate tap doesn't scroll. `testChangingTheCategoryMovesTheTransaction` failed when it tapped "Show all" before scrolling to it: the tap landed off screen. `reveal(_:_:)` scrolls first.
- `XCUIScreen.main.screenshot()` captures the outer display, black while the phone is open. `XCUIScreen.screens` lists both displays.

## What we ran

| Check | Result |
|---|---|
| `Tools/run-model-tests.sh` (Mac, Swift 6.4, `-default-isolation MainActor`) | 60 passed, 0 failed |
| Each model type in turn without `nonisolated`, same build | all 15 fail to compile |
| `swiftc -typecheck` of the app sources, iOS 27.1 and iOS 26.0 simulator targets | no errors, no warnings |
| `xcodebuild -quiet build-for-testing`, iPhone Duo simulator (iOS 27.1) | succeeded, no warnings |
| `duo-lint.py --strict` on the template | 0 findings (20 files) |
| The six UI tests, closed | 6 passed |
| The six UI tests, open | 6 passed |
| `testLayoutInThisPose`, partly folded (book) | passed; pane frames above |
| Launch and screenshots, closed and open, dashboard and detail | looked at: one column closed; two panes open, the gap on the fold, content clear of the status bar column and the vertical bar |
| Launched closed on a transaction, then opened | the transaction moved to the trailing pane; with the 600 ms wait, the dashboard matched a fresh launch |

## Not yet verified

- The open phone held tall, and set on a table like a laptop, with this template.
- Split View on the inner display, and the largest accessibility text sizes on the simulator.
- A real iPhone Duo: the fold's feel, 120 Hz, and whether the 600 ms wait is needed or enough there.
