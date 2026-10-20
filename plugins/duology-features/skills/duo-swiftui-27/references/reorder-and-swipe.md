# Reorder and swipe in containers that reflow

iOS 27 lets any SwiftUI container reorder its items and show swipe actions, not only `List` ([What's new in SwiftUI](https://developer.apple.com/videos/play/wwdc2026/269/?time=932), WWDC26 session 269). On iPhone Duo the containers that need this are the ones `List` can't build: a grid that has 2 columns closed and 4 open, a custom inbox column next to a reading pane, two lists on either side of the fold. This file has the full code, what we measured, and UI test tips.

## The pieces

| API | Put it on | What it does |
|---|---|---|
| `reorderable()` | the `ForEach` | Lets people lift its items with the system drag ([doc](https://developer.apple.com/documentation/swiftui/dynamicviewcontent/reorderable())). |
| `reorderable(collectionID:)` | each `ForEach`, when there are several | Tags the collection, so the drop reports which one it landed in. |
| `reorderContainer(for:isEnabled:move:)` | the stack, grid or layout that holds the `ForEach` | Shows the placeholder, animates, and calls `move` with a `ReorderDifference` ([doc](https://developer.apple.com/documentation/swiftui/view/reordercontainer(for:isenabled:move:))). |
| `reorderContainer(for:in:isEnabled:move:)` | the view that holds every collection | The same, with your collection ID type. |
| `swipeActionsContainer()` | the `ScrollView` or stack | Only one row open at a time; scrolling or a tap elsewhere closes it ([doc](https://developer.apple.com/documentation/swiftui/view/swipeactionscontainer())). A no-op on `List`, which already does this. |
| `swipeActions(edge:allowsFullSwipe:content:onPresentationChanged:)` | each row | The actions, plus a callback when they open and close. |

All need iOS 27.0 and are unavailable on tvOS. `ReorderDifference` holds `sources` (the IDs that moved) and `destination`, which has a `collectionID` and a `position` that is `.before(id)` or `.end` (iOS 27.1 SDK, `SwiftUI.swiftinterface`). Two more overloads take an `itemID:` key path when your items aren't `Identifiable`.

## Apply a difference to an array

The `move` closure only reports the change; your code applies it. This helper works for any `Identifiable` array and any collection ID type.

```swift
import SwiftUI

extension Array where Element: Identifiable {
    /// Moves the dragged items to where they were dropped.
    @available(iOS 27.0, *)
    mutating func applyReorder<CollectionID>(_ difference: ReorderDifference<Element.ID, CollectionID>) {
        let moved = Set(difference.sources)
        let moving = difference.sources.compactMap { id in first { $0.id == id } }
        var target = endIndex
        if case .before(let anchor) = difference.destination.position,
           let index = firstIndex(where: { $0.id == anchor }) {
            target = index
        }
        // Items that leave from before the target shift it left.
        let shift = self[..<target].filter { moved.contains($0.id) }.count
        removeAll { moved.contains($0.id) }
        insert(contentsOf: moving, at: target - shift)
    }
}
```

## A grid that reflows: 2 columns closed, 4 open

```swift
import SwiftUI

// requires: applyReorder (above)

struct Book: Identifiable, Hashable {
    let id: UUID
    var title: String
}

struct BookCover: View {
    let book: Book

    var body: some View {
        Text(book.title)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(.quaternary, in: .rect(cornerRadius: 12))
    }
}

@available(iOS 27.0, *)
struct ShelfGrid: View {
    @Binding var books: [Book]
    @Environment(\.horizontalSizeClass) private var widthClass

    var body: some View {
        let count = widthClass == .regular ? 4 : 2
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: count), spacing: 12) {
                ForEach(books) { book in
                    BookCover(book: book)
                }
                .reorderable()
            }
            .reorderContainer(for: Book.self) { difference in
                books.applyReorder(difference)
            }
            .padding()
        }
    }
}
```

- Keep the books in state above the grid (here a `Binding`), so a fold rebuilds the grid but not the order.
- Even column counts put the fold between columns ([Tech Talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=456)). Scrolling content may cross the fold, so the grid itself doesn't move off it.

## Two collections, one on each side of the fold

In book pose the fold splits the inner display into two regions. Two lists, one per region, make a natural planner, a playlist next to a library, or a cart next to a shelf. One container lets people drag across.

```swift
import SwiftUI

// nonisolated: in a MainActor-default target its Hashable conformance must not be actor-isolated.
nonisolated enum Lane: Hashable, Sendable { case later, today }

struct PlannerTask: Identifiable, Hashable {
    let id: Int
    var title: String
}

@available(iOS 27.0, *)
struct PlannerBoard: View {
    @State private var later: [PlannerTask] = []
    @State private var today: [PlannerTask] = []

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            lane(later, id: .later)
            lane(today, id: .today)
        }
        .reorderContainer(for: PlannerTask.self, in: Lane.self) { difference in
            move(difference)
        }
    }

    private func lane(_ tasks: [PlannerTask], id: Lane) -> some View {
        VStack(spacing: 8) {
            ForEach(tasks) { task in
                Text(task.title)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(.quaternary, in: .rect(cornerRadius: 10))
            }
            .reorderable(collectionID: id)
        }
        .frame(maxWidth: .infinity)
    }

    private func move(_ difference: ReorderDifference<PlannerTask.ID, Lane>) {
        let ids = Set(difference.sources)
        let moving = (later + today).filter { ids.contains($0.id) }
        later.removeAll { ids.contains($0.id) }
        today.removeAll { ids.contains($0.id) }
        var lane = difference.destination.collectionID == .later ? later : today
        var index = lane.endIndex
        if case .before(let anchor) = difference.destination.position,
           let found = lane.firstIndex(where: { $0.id == anchor }) {
            index = found
        }
        lane.insert(contentsOf: moving, at: index)
        if difference.destination.collectionID == .later { later = lane } else { today = lane }
    }
}
```

- The difference does not say which collection an item came from. Remove the IDs from every collection, then insert into the destination.
- To put the seam exactly on the fold, use `FoldSplitLayout` from `duo-layout` instead of the `HStack`.
- *Measured* error without `nonisolated`, with the Xcode 27 defaults (MainActor default isolation and `InferIsolatedConformances`): "main actor-isolated conformance of 'Lane' to 'Hashable' cannot satisfy conformance requirement for a 'Sendable' type parameter".
- A reorder container accepts only moves inside itself. To accept items dragged in from another window or another app in Split View, add a drop destination of your own ([session 271](https://developer.apple.com/videos/play/wwdc2026/271/?time=703)). Apple's `swiftui-whats-new-27` skill covers drag and drop.

## Swipe actions on a custom column

```swift
import SwiftUI

struct Message: Identifiable {
    let id: Int
    var subject: String
}

@available(iOS 27.0, *)
struct InboxColumn: View {
    @Binding var messages: [Message]
    @State private var openRows = 0

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(messages) { message in
                    Text(message.subject)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.background)
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                messages.removeAll { $0.id == message.id }
                            }
                        } onPresentationChanged: { isShown in
                            openRows += isShown ? 1 : -1
                        }
                    Divider()
                }
            }
        }
        .swipeActionsContainer()
    }
}
```

- Give each row an opaque background, so the actions slide in from behind it.
- Use `onPresentationChanged` to dim the row or hide a floating button while actions show.

## What we measured

iPhone Duo simulator, iOS 27.1, Xcode 27.1, 20 October 2026, with a probe app and XCUITest. The probe logged its size, size classes and whether the `.division` region was active, so each column names the pose the app really saw. Logs: [evidence.md](evidence.md#reorder-and-swipe).

| Check | Closed (382 pt wide, compact) | Open, held wide (867 pt, fold inactive) | Book (867 pt, fold active) |
|---|---|---|---|
| Grid: drag tile 0 onto tile 3 | 2 columns; order became 1, 2, 3, 0 | 4 columns, first to fourth across the fold line; same order | Same, across the active fold |
| Two lanes: drag card 1 onto card 12 | Card 1 moved into the trailing lane, before 12 | Same | Same, across the active fold |
| Swipe left on a row in a `LazyVStack` | Delete showed; `onPresentationChanged` fired once with `true` | Same | Same |

## UI tests that reach these gestures

- Drag with `press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)` between two elements' coordinates. A 1 s press, a `.slow` drag and a 0.5 s hold over the target moved items in every pose.
- `swipeLeft()` on the row's element opened the actions.
- The revealed action was a Button whose label read "Delete, Delete": the symbol's label and the title, joined. `app.buttons["Delete"]` matched nothing. `app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Delete'")).firstMatch` found it and its tap ran the delete (see [evidence.md](evidence.md#reorder-and-swipe)). When a query fails, print `app.debugDescription` to see the labels your test gets.
- More on gestures in UI tests on the Duo simulator: `duo-testing`.
