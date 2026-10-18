# List-detail

A list of items, and the details of the one you picked. Closed, the phone shows one of the two. Open, it shows both side by side.

Prior art: Microsoft's [list-detail pattern](https://learn.microsoft.com/en-us/previous-versions/dual-screen/design/list-detail) for Surface Duo and the list-detail entry in Android's [canonical layouts](https://developer.android.com/develop/ui/compose/layouts/adaptive/canonical-layouts). Apple's own example is Mail in the [HIG page for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo).

## Use it when

- Each item has a detail that makes sense on its own: mail, messages, notes, contacts, settings, orders.
- People move between items often and want to keep their place in the list.

Don't use it when the second view only makes sense next to the first (comments, tools, "up next"). That is a [supporting pane](supporting-pane.md). Don't use it to show the same data two ways. That is a [dual view](dual-view.md).

## How it behaves

| State | What shows | Who does it |
|---|---|---|
| Closed (outer display, compact width) | The list. Picking an item pushes the detail, with a Back button. | `NavigationSplitView` collapses to one stack ([talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)) |
| Open, flat (inner display, regular width) | List and detail side by side. The list column is narrower. | `NavigationSplitView`, with `columnVisibility` set to `.all` |
| Open, partly folded like a book | Both columns, now an even 50/50 split, one on each side of the fold | The system, for standard split views ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions), [talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=312)), as long as both columns show |
| Open, held tall (flat, or partly folded across) | The detail alone once an item is selected. Before that, the list over the placeholder. | You: `columnVisibility` set to `.detailOnly` or `.all` |

Both columns stay only if you ask for them. See [Column visibility](#column-visibility).

Apple's rule behind this: keep the same hierarchy on both displays, and add one level on the inner display when it helps. Mail shows a list or a message when closed and both when open ([HIG, Best practices](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Best-practices)).

## Apple APIs

| Need | SwiftUI | UIKit |
|---|---|---|
| The two columns | [`NavigationSplitView`](https://developer.apple.com/documentation/swiftui/navigationsplitview) | [`UISplitViewController`](https://developer.apple.com/documentation/uikit/uisplitviewcontroller) |
| Which columns show when expanded, and which one shows when collapsed | [`init(columnVisibility:preferredCompactColumn:sidebar:detail:)`](https://developer.apple.com/documentation/swiftui/navigationsplitview/init(columnvisibility:preferredcompactcolumn:sidebar:detail:)) (iOS 17) with [`NavigationSplitViewVisibility`](https://developer.apple.com/documentation/swiftui/navigationsplitviewvisibility) | `preferredDisplayMode`, and the delegate method `splitViewController(_:topColumnForCollapsingToProposedTopColumn:)` |
| Wide or tall | [`onGeometryChange(for:of:action:)`](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)) on the split view | `viewWillTransition(to:with:)` |
| Placeholder when nothing is selected | [`ContentUnavailableView`](https://developer.apple.com/documentation/swiftui/contentunavailableview) | your own empty view |

No Duo-only API is needed. The split view does the fold split itself, once both columns show.

## Column visibility

Set `columnVisibility` yourself. Don't leave it at `.automatic`.

Why: in the gallery app, with automatic visibility, the open phone showed the selected message alone, full width. In book pose its lines ran across the fold. With `.all`, both columns stay. In book pose the system then splits them 50/50, and the edge between them sits in the middle of the fold region (measured on the iOS 27.1 simulator, 18 October 2026).

Choose the value from the split view's own shape and the selection. Never from the pose, the device or the orientation.

| The split view is | Selection | `columnVisibility` | What shows |
|---|---|---|---|
| Wider than tall (open flat, or book) | Any | `.all` | List and detail side by side. 50/50 at the fold when partly folded. |
| Taller than wide (held tall, or tabletop) | None | `.all` | The list over the placeholder |
| Taller than wide | An item | `.detailOnly` | The detail fills the window. The sidebar button brings the list back. |
| Collapsed (closed) | Any | Ignored | One stack. `preferredCompactColumn` picks the top. |

Held tall, `.all` lays the list over the detail. That is why the tall case switches to `.detailOnly` once there is something to read. Apple's doc says a collapsed split view ignores the visibility binding ([`NavigationSplitView`](https://developer.apple.com/documentation/swiftui/navigationsplitview)), so the same rule is safe on the closed phone.

Run the rule again when the shape changes and when the selection changes. The recipe does both.

## Rules

1. Build it with `NavigationSplitView`. Don't build list-detail from an `HStack` or an `ArrangementView`. Apple says arrangements don't provide navigation, and that navigation containers belong around an arrangement, never inside one ([HIG, Arrangement views](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Arrangement-views)).
2. Keep the selection above the split view, in `@SceneStorage`, `@State` or your model. The split view then keeps it through fold, unfold and rotation.
3. Give the detail column a placeholder. Open the phone on the list and the detail column must still show something useful.
4. Put list actions (sort, filter, compose) on the list column's toolbar, and item actions on the detail's toolbar. In a split view only the detail column's bar goes vertical; the other columns keep horizontal bars above their own content ([talk 111462](https://developer.apple.com/videos/play/tech-talks/111462/), [hub, Optimize bars](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)). The HIG uses Mail as the example: list controls stay above the list ([HIG, Vertical controls](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls)).
5. Set `columnVisibility` from the split view's shape: `.all` when it is wider than tall, `.detailOnly` when it is taller than wide and an item is selected. Left at `.automatic`, the selected item can fill the open phone and run across the fold.
6. Let the system size the columns. It moves them to 50/50 when the phone folds. If you set `navigationSplitViewColumnWidth`, check in Device Hub that the fold still gets the even split. (unverified)

## Pitfalls

- **Swapping views on size class.** `if sizeClass == .compact { ListScreen() } else { SplitScreen() }` builds a new view tree when the phone opens. You lose the scroll position and the selection. Use one `NavigationSplitView` for both.
- **Losing the detail on close.** Android's guidance is a good test: if the detail is showing when the window narrows, keep showing the detail, not the list ([canonical layouts](https://developer.android.com/develop/ui/compose/layouts/adaptive/canonical-layouts)). Check that your app does this when you close the phone.
- **Automatic column visibility.** `NavigationSplitView(preferredCompactColumn:)` alone leaves the columns to the system. In the gallery the open phone then showed the message alone, across the fold. Pass `columnVisibility` too.
- **Fixed widths.** `frame(width: 320)` on the list fights the fold split and Split View. Use the split view's own sizing.
- **An arrangement inside the detail column.** Apple's hub says to avoid an `ArrangementView` inside a navigation split view, a list or a scroll view ([hub, Arrange views in different poses](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)). The HIG is looser about split views; Duology follows the hub. To add a side pane next to the detail, use `inspector(isPresented:content:)` on the detail column: see Combining patterns in SKILL.md.

## Recipe

Self-contained. It typechecks against the iOS 27.1 simulator SDK and also builds for an iOS 26 target.

```swift
import SwiftUI

struct Note: Identifiable, Hashable {
    let id: Int
    var title: String
    var body: String
}

struct NotesListDetail: View {
    let notes: [Note]

    // Selection lives above the split view, so fold, unfold and rotation keep it.
    // Scene storage also brings it back after the system ends the app.
    @SceneStorage("notes.selection") private var selection: Note.ID?
    // Which column a collapsed split view (outer display) shows on top.
    @State private var compactColumn = NavigationSplitViewColumn.sidebar
    // Set by updateColumns(). Left at .automatic, the open phone showed the
    // selected note alone, and in book pose its lines ran across the fold.
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var isWide = true

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $compactColumn) {
            List(notes, selection: $selection) { note in
                Text(note.title)
            }
            .navigationTitle("Notes")
            .toolbar {
                // List actions stay with the list column (horizontal, above the list).
                ToolbarItem {
                    Button("Sort", systemImage: "arrow.up.arrow.down") {}
                }
            }
        } detail: {
            if let note = notes.first(where: { $0.id == selection }) {
                NoteDetail(note: note)
            } else {
                // Open with nothing selected: show a placeholder, never an empty pane.
                ContentUnavailableView("No Note Selected", systemImage: "note.text")
            }
        }
        // The split view's own shape, never the pose or the orientation.
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width > proxy.size.height
        } action: { wide in
            isWide = wide
            updateColumns()
        }
        .onChange(of: selection) {
            updateColumns()
        }
    }

    /// Wide (open flat, or folded like a book): both columns, so the system can
    /// put one on each side of the fold. Tall: the note alone once there is one,
    /// else the list over the placeholder. Collapsed (closed), the split view
    /// ignores this.
    private func updateColumns() {
        columnVisibility = isWide || selection == nil ? .all : .detailOnly
    }
}

struct NoteDetail: View {
    let note: Note

    var body: some View {
        ScrollView {
            Text(note.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(note.title)
        .toolbar {
            // Detail actions go in the detail column. On iPhone Duo they can move
            // to the vertical bar on the side.
            ToolbarItem {
                Button("Share", systemImage: "square.and.arrow.up") {}
            }
        }
    }
}
```

`@SceneStorage` takes `Bool`, `Int`, `Double`, `String`, `URL`, `Date`, `Data`, their optionals, and enums with `Int` or `String` raw values. For other ID types, store a string form. For the rest of the state that must survive a fold, see the `duo-continuity` skill.

## Test it

In Device Hub, with the iPhone Duo simulator ([Device Hub guide](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)):

1. Open: pick the third item. Close: the detail of item 3 shows, with Back to the list.
2. Closed, on the list, scroll down. Open: the list keeps its scroll position and the detail shows the placeholder or the selection.
3. Open, pick an item, then Partially Open: the list stays, the two columns become equal halves, and nothing sits in the fold.
4. Open, held tall, or Partially Open then Rotate Right (tabletop): with an item selected the detail fills the window, and the sidebar button brings the list back.
5. Split View on the inner display: drag the app by its home indicator to one side; it collapses like the closed phone.

## Gallery screen

[`samples/DuologyGallery/DuologyGallery/Patterns/ListDetailView.swift`](https://github.com/Kimeur/duology/blob/main/samples/DuologyGallery/DuologyGallery/Patterns/ListDetailView.swift)

## Sources

IDs point to [`reference/sources.md`](https://github.com/Kimeur/duology/blob/main/reference/sources.md): D1 (hub), D2 (HIG), V1 (talk 111461), V2 (talk 111462), V3 (talk 111463), P1c (Microsoft list-detail), P2 (Android canonical layouts).
