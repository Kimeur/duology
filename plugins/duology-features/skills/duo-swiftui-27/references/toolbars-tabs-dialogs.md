# Tabs, toolbars and dialogs on iPhone Duo

The iOS 27 tab, toolbar and dialog APIs, with what the iPhone Duo simulator showed. For how the vertical bar orders, labels and ranks items, read `duo-navigation` first; this file adds the iOS 27 pieces. Logs and dates: [evidence.md](evidence.md).

## The prominent tab

`TabRole.prominent` (iOS 27.0) gives one tab a separate place at the trailing end of the tab bar ([doc](https://developer.apple.com/documentation/swiftui/tabrole/prominent), [session 269](https://developer.apple.com/videos/play/wwdc2026/269/?time=307)). Only one tab gets the treatment. With no prominent tab, a `.search` tab may get it by default.

*Measured* on the iPhone Duo simulator (iOS 27.1, 20 Oct 2026), a `TabView` with Shop, Packs, Saved and a prominent Cart:

| Pose | Tab bar | Prominent tab |
|---|---|---|
| Closed (outer display) | Vertical, trailing side, symbols only | A separate round button at the foot of the bar, below the other three |
| Open, held wide | Vertical, trailing side, symbols only | The same, at the foot |
| Inner display held tall (Duology's tabletop) | Horizontal, at the bottom, symbols and titles | A separate round button at the trailing end |

What this means:

- In the vertical bar the prominent tab is the one nearest the thumb at the bottom. Use it for the action people come back to (cart, compose, new), not for a section they browse.
- The vertical bar shows no titles, so pick a symbol that reads alone. The title still shows held tall.
- Don't also add your own floating button for the same action. It would compete with the prominent tab at the same corner.

## Ranking items as the column fills

`visibilityPriority(_:)` (iOS 27.0) decides which items overflow first, `ToolbarOverflowMenu` (iOS 27.0) sends items straight to the overflow menu, and `topBarPinnedTrailing` (iOS 27.0) keeps one item in place; a pinned item overflows only while search is active and space runs out ([doc](https://developer.apple.com/documentation/swiftui/toolbaritemplacement/topbarpinnedtrailing)). `duo-navigation` shows them together in one toolbar, with the order they take in the vertical bar.

On iPhone Duo the vertical bar shares the side column with the status bar and the Dynamic Island. Apple says the island expands vertically as Live Activities arrive, and app controls collapse into the overflow menu when there isn't room ([Tech Talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=336)). So the same screen can show fewer items while a delivery or a timer runs. Rank every group, not only the long toolbars. `duo-system-surfaces` has what we measured about the island's room in the column.

## Minimizing the navigation bar on scroll

`toolbarMinimizationBehavior(_:for:)` (iOS 27.0) takes `.automatic`, `.onScrollDown`, `.onScrollUp` or `.never` (the last three iOS only), and `.navigationBar` is the placement it supports ([doc](https://developer.apple.com/documentation/swiftui/view/toolbarminimizationbehavior(_:for:))). Two companions, both for `.navigationBar` only:

- `toolbarMinimizationSafeAreaAdjustment(_:for:)`: by default the safe area follows the bar as it shrinks. Pass `.disabled` to keep content still, for full-bleed media under the bar ([doc](https://developer.apple.com/documentation/swiftui/view/toolbarminimizationsafeareaadjustment(_:for:))).
- `toolbarMinimizationRestoration(_:for:)`: `.atScrollEdge` brings the bar back only at the top of the content, instead of on any scroll up. It works only with `.onScrollDown` ([doc](https://developer.apple.com/documentation/swiftui/view/toolbarminimizationrestoration(_:for:))).

```swift
import SwiftUI

@available(iOS 27.0, *)
struct StickerFeed: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack {
                    ForEach(0..<100, id: \.self) { Text("Sticker \($0)").padding() }
                }
            }
            .navigationTitle("Stickers")
            .toolbarMinimizationBehavior(.onScrollDown, for: .navigationBar)
            .toolbarMinimizationRestoration(.atScrollEdge, for: .navigationBar)
        }
    }
}
```

The WWDC26 talk and Xcode's `swiftui-whats-new-27` skill spell the modifier `toolbarMinimizeBehavior` ([session 269](https://developer.apple.com/videos/play/wwdc2026/269/?time=456)). That name is not in the iOS 27.1 SDK; code that uses it doesn't compile.

On Duo the navigation bar's buttons live in the vertical bar, closed and open held wide, while the title stays at the top. Apple doesn't say what minimizing does there. *Measured* with a screen that had a large title, a Share button and a bottom-bar Add button, scrolled by a UI test:

| Setting | Closed | Open, held wide | Book |
|---|---|---|---|
| `.onScrollDown` | Top inset 82 pt shrank to 24 pt; the title scrolled away | Same, 82 to 24 pt | Same, 82 to 24 pt |
| `.never` (control) | Top inset stayed 82 pt | not run | not run |

In every run the side column did not change: the trailing inset stayed 84 pt, and Share and Add stayed in place. So on Duo, minimizing gives back height at the top, not width at the side.

## Dialogs from an optional item

`alert(_:item:actions:)`, `alert(_:item:actions:message:)`, `confirmationDialog(_:item:titleVisibility:actions:)` and `confirmationDialog(_:item:titleVisibility:actions:message:)` present while the binding holds a value, and pass the unwrapped value to the closures, like `sheet(item:)` ([session 269](https://developer.apple.com/videos/play/wwdc2026/269/?time=1151), [doc](https://developer.apple.com/documentation/swiftui/view/alert(_:item:actions:))). They are new in the iOS 27 SDK but inlined into your app, so they build for older targets too.

*Measured* with a confirmation dialog opened on the closed phone, then the phone opened, then folded like a book (screenshots of both displays after each step):

- The dialog stayed on screen through both changes, with the item's title in its button. The item lives in `@State`, which the fold didn't reset.
- Closed and open flat, it showed as a bubble above its button.
- In book pose it moved beside the button, on the leading side, clear of the fold. The button sat a little left of the middle of the display.

Apple says system components such as sheets, alerts and menus nudge themselves out of the fold ([Tech Talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=568)), and that held like a book, alerts move toward the trailing side ([Tech Talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=251)). Our dialog went leading, probably because it was anchored to a button just left of the fold (our reading). Either way, don't position dialogs yourself, and keep the button that opens one out of the fold region. That run's log did not record the fold state, so the book pose rests on the pose tool's report and the dialog's move (see [evidence.md](evidence.md#dialogs)).
