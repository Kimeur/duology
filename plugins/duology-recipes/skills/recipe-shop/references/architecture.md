# Architecture of the shop recipe

How the generated project fits together, why each piece is where it is, and what we ran to check it. Paths use `<App>` for the app name you gave `new-project.sh`. StoreKit has its own page: [storekit.md](storekit.md).

## The layers

```text
RootView                         owns ShopModel and Store (survive every layout change); reads the width class
 ├─ NavigationStack(path:)       path computed from the selection and the basket
 │   ├─ ShopScreen               measures its width and fold
 │   │   └─ FoldPanes            the grid alone, or the grid and a pack split on the fold
 │   │       ├─ leading pane     ShopColumn: PlusCard, SpotlightCard, the pack grid
 │   │       └─ trailing pane    PackDetail (open, a pack picked)
 │   ├─ PackScreen               closed only: PackDetail, pushed
 │   └─ BasketScreen             ActionPanes: lines | total, Plus offer, Buy, Restore
 └─ fullScreenCover              PlusScreen: ActionPanes: benefits | plans, Subscribe, terms
```

The model (`<App>/Model/`) imports only Foundation. `Store` is the only file that imports StoreKit for purchases; views read prices from it.

## The grid

`ShopScreen` measures itself inside the container margins with `onPaneGeometryChange` (width and the fold's x values only, so scrolling never re-lays it out). `ShopColumn` then builds one `DuoColumns` grid from the design tokens: 4 columns in compact width, 8 in regular, with the fold as the middle gutter. It groups the same grid twice:

| | Columns | Packs (span 2) | Cards (span 4) | Gap at the fold |
|---|---|---|---|---|
| Closed, 362 pt grid | 4 | 2 per row, 175 pt | 1 per row | none |
| Open, flat, 847 pt grid | 8 | 4 per row, 2 per side | 1 per side | 16 pt, centred on the fold line |
| Open, partly folded | 8 | 4 per row, 2 per side | 1 per side | the fold's frame, 40 pt |
| Open, a pack picked | 4 in the leading pane | 2 per row | 1 per row | the fold is the gap between the panes |
| Accessibility text sizes | same | spans double: 1 per row closed, 1 per side open | full width, or one side | same |

The numbers come from `duo-design-system`'s worked example and are checked in `Tools/ModelTests/main.swift`. Each `LazyVGrid` uses `DuoColumns.gridItems` (fixed widths and the real gap after each column) and `.frame(minWidth: 0, maxWidth: .infinity)`, so the measured width can shrink when the phone closes.

Two details keep the grid tidy across the fold:

- The two halves differ in width next to the vertical bar. With an aspect-ratio image, the left half's tiles came out taller than the right half's (*measured*). A fixed art height (`@ScaledMetric`, 116 pt at the default text size) and fixed line counts give every tile in a row the same height.
- The "All packs" header and its count sit in the first card's width, so no text crosses the fold.

`ShopScreen` uses `PaneFrames` only when the width is regular and a pack is picked. The leading pane then gets compact width (`FoldPanes` sets it), so the same `ShopColumn` lays out 4 columns there.

## ActionPanes: the basket and the paywall

`ActionPanes(isTwoPane:content:panel:action:footer:)` in `Shared/ActionPanes.swift`:

- Regular width: `FoldPanes` with `PaneFrames`. The content scrolls in the leading pane; the panel, the main button and the footer scroll in the trailing pane. Partly folded, the fold is the gap, so the button is never in it.
- Compact width: one scroll view (content, panel, footer) and the main button in `.safeAreaInset(edge: .bottom)`, so Buy or Subscribe is always in reach on the outer display.

The paywall is a `fullScreenCover`, not a sheet: a sheet on the inner display is narrower than the window, which leaves no room for two panes.

## One purchase, start to finish

1. Buy in the basket starts `Task { await model.checkOut(with: purchase) }`, where `purchase` is the view's `PurchaseAction`.
2. `ShopModel.checkOut` makes a `CheckoutRun` from the basket, or resumes a stopped one.
3. For each `next` pack: `start`, then `Store.buy(id, with:)`, then `finish` with the outcome.
4. `Store.buy` calls the purchase action. A verified transaction is finished and entitlements are read again; unverified fails; `.pending` and `.userCancelled` pass through.
5. A cancel or an error stops the run, and the button reads "Buy the rest". Pending moves on.
6. When every line is bought or pending, the summary says how many packs are yours, bought and pending packs leave the basket, and the button reads "Back to the shop".
7. Meanwhile `Store.ownership` changes, `RootView`'s `onChange` calls `ownershipChanged()`, and the basket drops what the person can now use. It waits while a purchase is in flight.

The checkout lives in the model, above the stack, so a fold or an unfold during checkout keeps it (unverified with a purchase in flight; the StoreKit sheet's own behaviour across a fold is unverified).

## Unfolding on a pushed pack

Same issue and workaround as `recipe-finance-dashboard` ([its architecture page](https://github.com/Kimeur/duology/blob/main/plugins/duology-recipes/skills/recipe-finance-dashboard/references/architecture.md#unfolding-on-a-pushed-screen)). *Measured here too*, with a readout of the shop's own geometry: popped during the unfold, the shop sat at x = −2 pt, 911 pt wide, with a right safe-area inset of 42 pt instead of 84 pt, and the pack's close button under the vertical bar. With the 600 ms wait in `RootView`, it matched a fresh launch: x = 20 pt, 847 pt wide, right inset 84 pt.

## Model API

| Member | What it does |
|---|---|
| `Catalog.packs(in:)`, `pack(_:)`, `plan(_:)`, `productIDs`, `yearlyPlan` | Lookups and the IDs to ask StoreKit for. |
| `Cart.add(_:)`, `toggle(_:)`, `remove(_:)`, `removeUnlocked(_:)` | The basket. A pack goes in once; owned packs and Plus empty it. |
| `Cart.total(prices:)`, `suggestsPlus(prices:yearly:)` | An exact `Decimal` total, or nil while a price is missing; Plus when it costs less. |
| `Ownership(entitlements:catalog:)`, `unlocks(_:)`, `bought(_:)`, `hasPlus` | Entitlement product IDs sorted into packs and a plan. Unknown IDs unlock nothing. |
| `CheckoutRun` | `next`, `start`, `finish`, `resume`, `drop`, `isFinished`, `bought`, `pending`, `remaining`, `failure`. |
| `PlanMath.percentSaved(yearly:monthly:)` | Whole percent, rounded down; nil when the year saves nothing. |
| `DuoColumns`, `PaneFrames`, `DuoFold` | The grid and pane math. |

Every type is `nonisolated` and `Sendable`. *Measured:* removing `nonisolated` from any one of the 13 types stops the test build, because one check runs the model in `Task.detached` and calls a method, a computed property or `==` on each.

## Launch switches

Debug builds only. The last copy of a switch wins.

| Switch | Effect |
|---|---|
| `-uiTesting` | Animations off. |
| `-select ID` | Open a pack, for example `-select pack.harbor`. |
| `-category NAME` | One category in the grid, for example `-category rain`. |
| `-basket ID,ID` | Start with these packs in the basket. |
| `-openBasket`, `-openPlus` | Start on the basket, or on the paywall. |

## The UI tests

| Test | Checks |
|---|---|
| `testPricesComeFromTheStoreKitConfiguration` | A tile and the Plus card show StoreKit's prices. |
| `testPacksSitInEvenColumns` | An even number of packs per row: 2 closed, 4 open, 2 beside an open pack. |
| `testPickingAPackShowsItsDetail` | A tile opens its pack; open, side by side, the tile stays selected, the close button is 44 pt; closing brings the grid back. |
| `testAddingAPackFillsTheBasket` | The basket button turns to "In basket"; the basket lists the pack with its price. |
| `testBasketTotalsAndRemoves` | $2.99 + $3.99 + $1.99 = $8.97; Buy says "Buy 3 packs"; open, Buy is in the trailing pane; closed, it is hittable; removing a pack updates the total. |
| `testCheckoutBuysEveryPackInTheBasket` | Two purchases go through; the shop shows them owned; the basket is empty. |
| `testAFailedPurchaseStopsCheckoutUntilResumed` | A simulated network error stops checkout ("Buy the rest"); after clearing it, the rest goes through. |
| `testAskToBuyLeavesThePackWaiting` | Pending is not a failure: the summary says it is waiting for approval. |
| `testPlusShowsBothPlansFromStoreKit` | Both plans with StoreKit's prices; Subscribe enabled and in reach; open, the plans sit in the trailing pane; a plan can be picked; Close goes back. |
| `testSubscribingUnlocksEveryPack` | "Try it free" for the yearly plan; the paywall closes; every pack reads "included with Plus"; the basket empties. |
| `testLayoutInThisPose` | Prices show; open, the gap between the shop and the pack is a gutter or the fold (12 to 60 pt). Attaches pane frames and a screenshot of each display. |

Duo simulator notes for these tests (*measured*):

- `XCUIScreen.main.screenshot()` and `app.screenshot()` capture the outer display, black while the phone is open. `XCUIScreen.screens` lists both displays.
- A lazy grid's tiles don't exist until they scroll in: on the closed phone the 12th tile was missing. The checkout test uses packs from the first row.
- A coordinate tap doesn't scroll. Closed, the monthly plan sits below the screen under the pinned Subscribe button; `reveal(_:_:above:)` scrolls it into view first.
- An accessibility identifier on a plain container replaced the identifiers of the rows inside it. `.accessibilityElement(children: .contain)` before the identifier keeps both.
- `accessibilityValue` on a toolbar button came back empty in XCUITest, so the tests open the basket to check it is empty.

## What we ran

| Check | Result |
|---|---|
| `Tools/run-model-tests.sh` (Mac, Swift 6.4, `-default-isolation MainActor`) | 67 passed, 0 failed |
| Each model type in turn without `nonisolated` | all 13 fail to compile |
| `swiftc -typecheck` of the app sources, iOS 27.1 and iOS 26.0 simulator targets | no errors, no warnings |
| `xcodebuild -quiet build-for-testing`, iPhone Duo simulator (iOS 27.1) | succeeded, no warnings |
| `duo-lint.py --strict` on the template | 0 findings (25 files) |
| The eleven UI tests, closed | all passed, final template |
| The eleven UI tests, open | all passed, on the template before two small edits (the default plan now comes from the catalog; two tests scroll before they tap), both checked closed |
| `testLayoutInThisPose`, partly folded (book) | passed: grid pane 20 to 455.7 pt, pack pane from 495.7 pt (flat: 467.7 and 483.7) |
| Screenshots closed and open: shop, pack, basket, Plus | looked at: 2 and 4 per row, nothing in the fold, buttons in one pane, content clear of the status bar column and the vertical bar |
| Closed on a pack, opened, closed | the pack moved to the trailing pane and back to its own screen |
| Unfold on a pushed pack, with and without the 600 ms wait | stale insets without it; same as a fresh launch with it |

## Not yet verified

- The open phone held tall, or set on a table like a laptop; the basket and Plus screens partly folded (their split is the same `PaneFrames`).
- Folding during a purchase, with StoreKit's sheet on screen.
- Split View on the inner display.
- A real iPhone Duo, and real App Store Connect products in the Sandbox.
