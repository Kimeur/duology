# Supporting pane

Main content, plus a narrower pane that only makes sense next to it: comments on an article, a transcript beside a podcast, "up next" beside a player, tools beside a document. Closed, the pane moves into a sheet. Open, it sits beside the main content.

Prior art: the supporting pane in Android's [canonical layouts](https://developer.android.com/develop/ui/compose/layouts/adaptive/canonical-layouts) and Microsoft's [companion pane](https://learn.microsoft.com/en-us/previous-versions/dual-screen/design/companion-pane) for Surface Duo. Apple's own example is the Podcasts transcript beside Now Playing in [talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=560).

## Use it when

- The pane depends on the main content. On its own it means nothing. (Android uses this test to tell a supporting pane from list-detail.)
- Both must stay fully visible while you use them. Apple's advice: pick a split arrangement when the two have a main-detail relationship and neither should ever be covered ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=879)).

Use an overlay arrangement instead when the pane is foreground over a background you can scroll, like reading controls over text. Use [list-detail](list-detail.md) when the second view is meaningful alone.

## How it behaves

| State | What shows |
|---|---|
| Closed (outer display, compact width) | Main content only. A toolbar button opens the pane in a sheet. |
| Open, flat, held wide | Main content and the pane side by side. The pane is narrower. |
| Open, partly folded like a book | One on each side of the fold. The arrangement adapts to the fold for you ([hub](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)). |
| Open, held tall | Main content only, plus the button (with a horizontal-only split). |
| Split View, half the inner display | Main content only, plus the button. |

## Apple APIs

| Need | SwiftUI | UIKit |
|---|---|---|
| Two views that adapt to the display and the fold | [`ArrangementView`](https://developer.apple.com/documentation/swiftui/arrangementview) | [`UIArrangementViewController`](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller) |
| Side by side only | [`.split.axes(.horizontal)`](https://developer.apple.com/documentation/swiftui/splitarrangementviewstyle/axes(_:)) | `updateArrangement(.split.axes(.horizontal))` |
| A narrower pane | [`splitArrangementLayoutRatio(minHorizontal:idealHorizontal:maxHorizontal:…)`](https://developer.apple.com/documentation/swiftui/view/splitarrangementlayoutratio(minhorizontal:idealhorizontal:maxhorizontal:minvertical:idealvertical:maxvertical:)) or [`splitArrangementLayoutSize(minWidth:…)`](https://developer.apple.com/documentation/swiftui/view/splitarrangementlayoutsize(minwidth:idealwidth:maxwidth:minheight:idealheight:maxheight:)) | `UISplitArrangement.ViewProperties` |
| The pane on a closed phone | [`sheet(isPresented:)`](https://developer.apple.com/documentation/swiftui/view/sheet(ispresented:ondismiss:content:)) with [`presentationDetents(_:)`](https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:)) | `UISheetPresentationController` |

All arrangement APIs are iOS 27.1. Mark the screen `@available(iOS 27.1, *)` and keep a plain layout for older systems.

Alternative: [`inspector(isPresented:content:)`](https://developer.apple.com/documentation/swiftui/view/inspector(ispresented:content:)) (iOS 17) is a trailing column at regular width and a sheet at compact width. Apple's hub says the system gives inspectors horizontal bars on iPhone Duo. Whether an inspector moves off the fold when the phone folds is not documented. (unverified)

## Rules

1. Put the main content in `primary` and the pane in `secondary`. When the arrangement can only show one view, it shows the primary ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=720)).
2. Restrict the split to `.horizontal` when the pane must sit beside the content, never below it.
3. Size the pane with a ratio or a min/ideal/max range. Never a fixed point width.
4. Put the `ArrangementView` inside your `NavigationStack`, not around it, and never inside a `List`, `ScrollView` or `NavigationSplitView` ([hub](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo), [HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Arrangement-views)).
5. Keep one model for the pane. The inline pane and the sheet read the same comments and the same draft, so nothing is lost when the phone opens with the sheet up.
6. Offer the pane on every display. Closed, it is one tap away. Apple: don't tie functionality to one pose ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=222)).

## What we measured

On the iOS 27.1 iPhone Duo simulator, open and flat (Xcode 27.1, 16 Oct 2026):

- In a frame taller than wide, `.split.axes(.horizontal)` showed only the primary. The secondary still ran `onAppear` and got the full size. It was alive, just not visible. So you can't use the secondary's `onAppear` or `onDisappear` to learn whether the pane is on screen.
- `.splitArrangementLayoutRatio(0.3)` on the primary gave it 30% of a wide frame.
- `splitArrangementAxis` read `nil` inside both views, even in a working horizontal split. Don't build on it until you have checked it folded. (unverified when folded)

Because no API reports "the secondary is hidden", the recipe below mirrors Apple's documented rule: a split goes side by side when the view is wider than tall, and size class is one of its inputs ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=560)). Duology's earlier research notes also report that an arrangement showed only its first view on the closed phone held sideways (not re-measured here). Check the rule in Device Hub for your screen.

## Recipe

Self-contained. It typechecks against the iOS 27.1 simulator SDK, also with an iOS 26 deployment target.

```swift
import SwiftUI

@MainActor @Observable
final class ArticleModel {
    var comments = ["Great read.", "Source for the second chart?"]
    var draft = ""
}

@available(iOS 27.1, *)
struct ArticleWithComments: View {
    @State private var model = ArticleModel()
    @State private var showsCommentsSheet = false
    @State private var paneFitsBeside = false
    @Environment(\.horizontalSizeClass) private var widthClass

    var body: some View {
        NavigationStack {
            ArrangementView {
                ArticleBody()
            } secondary: {
                CommentsPane(model: model)
                    // A narrower pane. A ratio, not a point width.
                    .splitArrangementLayoutRatio(minHorizontal: 0.3, idealHorizontal: 0.36, maxHorizontal: 0.42)
            }
            // Beside, never below. When the pane can't sit beside, only the article shows.
            .arrangementViewStyle(.split.axes(.horizontal))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                // Mirrors Apple's documented split rule. Check it in Device Hub.
                paneFitsBeside = widthClass == .regular && size.width > size.height
            }
            .navigationTitle("Article")
            .toolbar {
                if !paneFitsBeside {
                    ToolbarItem {
                        Button("Comments", systemImage: "text.bubble") {
                            showsCommentsSheet = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showsCommentsSheet) {
                CommentsPane(model: model)
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: paneFitsBeside) { _, fits in
                // Unfolded with the sheet up: the pane is now inline, so drop the sheet.
                if fits { showsCommentsSheet = false }
            }
        }
    }
}

struct ArticleBody: View {
    var body: some View {
        ScrollView {
            Text("Long article text…")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
}

struct CommentsPane: View {
    @Bindable var model: ArticleModel

    var body: some View {
        VStack(spacing: 0) {
            List(model.comments, id: \.self) { Text($0) }
            TextField("Add a comment", text: $model.draft)
                .textFieldStyle(.roundedBorder)
                .padding()
        }
    }
}
```

UIKit, with the same calls as the UIKit sample in Apple's hub:

```swift
import UIKit

@available(iOS 27.1, *)
@MainActor
func makeArticleScreen(article: UIViewController, comments: UIViewController) -> UINavigationController {
    let arrangement = UIArrangementViewController()
    arrangement.setViewController(article, for: .primary)
    arrangement.setViewController(comments, for: .secondary)
    // Side by side only. Taller than wide, only the article shows.
    arrangement.updateArrangement(.split.axes(.horizontal))
    // The arrangement goes inside the navigation controller, never around it.
    return UINavigationController(rootViewController: arrangement)
}
```

## Pitfalls

- **A pane you can't reach when closed.** With a horizontal-only split, the closed phone shows only the primary. Without the toolbar button, comments vanish.
- **Two copies of the state.** If the sheet and the inline pane each own their draft, typing in the sheet and then opening the phone loses the text.
- **Duplicate controls.** Hide the "Comments" button when the pane is already beside the content.
- **The pane as primary.** If you swap them, the closed phone shows comments with no article.

## Test it

1. Open: the pane sits beside the article, narrower.
2. Partially Open: one view on each side of the fold, no control in the fold.
3. Close: only the article, and a Comments button. Tap it: the sheet shows the same comments.
4. Type a draft in the sheet, then open the phone: the sheet goes away and the draft is in the inline pane.
5. Open, held tall, and in Split View: the button comes back.

## Gallery screen

[`samples/DuologyGallery/DuologyGallery/Patterns/SupportingPaneView.swift`](../../../../../samples/DuologyGallery/DuologyGallery/Patterns/SupportingPaneView.swift)

## Sources

IDs point to [`reference/sources.md`](../../../../../reference/sources.md): D1 (hub), D2 (HIG), V3 (talk 111463), V6 (talk 111466), P1f (Microsoft companion pane), P2 (Android canonical layouts).
