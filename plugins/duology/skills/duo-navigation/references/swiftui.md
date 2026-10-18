# SwiftUI recipes for bars on iPhone Duo

More code for [`../SKILL.md`](../SKILL.md). Every block typechecks on its own against the iOS 27.1 simulator SDK. Rules and sources: [`bar-rules.md`](bar-rules.md).

## Replace a hand-drawn bar

A row of buttons in `safeAreaInset(edge: .bottom)` or `.overlay(alignment: .bottom)` is your own content. It never joins the vertical bar, so on the closed phone it stays at the bottom while the system bars move to the side. Icon-only labels give the overflow menu no title to show. The old code looked like this:

```text
.safeAreaInset(edge: .bottom) {
    HStack {
        Button { share() } label: { Image(systemName: "square.and.arrow.up") }
        Spacer()
        Button("Start Timer") { startTimer() }
        Spacer()
        Button { save() } label: { Image(systemName: "bookmark") }
    }
    .padding()
    .background(.bar)
}
```

Move every action into `.toolbar`, give each one a symbol and a title, and drop the spacers:

```swift
import SwiftUI

struct RecipeScreen: View {
    @State private var isSaved = false
    @State private var units = "Metric"

    var body: some View {
        NavigationStack {
            ScrollView {
                Text("Ingredients and steps")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentMargins(for: .container, edges: .horizontal)
            }
            .navigationTitle("Recipe")
            .toolbar {
                // Was a Menu with an Image-only label.
                ToolbarItem(placement: .primaryAction) {
                    Menu("Units", systemImage: "ruler") {
                        Picker("Units", selection: $units) {
                            Text("Metric").tag("Metric")
                            Text("Imperial").tag("Imperial")
                        }
                    }
                }
                // Was the hand-drawn bottom row. Now it joins the vertical bar.
                ToolbarItemGroup(placement: .bottomBar) {
                    ShareLink(item: "Pancakes")
                    Button("Start Timer", systemImage: "timer") {}
                    Button(isSaved ? "Unsave" : "Save",
                           systemImage: isSaved ? "bookmark.fill" : "bookmark") {
                        isSaved.toggle()
                    }
                }
                .visibilityPriority(.high)
            }
        }
    }
}
```

- `ShareLink` already carries a symbol and a title.
- A text-only button such as "Start Timer" stays horizontal. Give it a symbol so it can move.
- A lone floating button, such as an Add button, may stay in an overlay. Read `toolbarVerticalEdge` and keep it on the side away from the bar.

## Split view: list actions on the list, item actions on the detail

The detail column joins the vertical bar. The sidebar keeps a horizontal bar, so its actions stay above the list they act on ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls)).

```swift
import SwiftUI

struct Note: Identifiable, Hashable {
    let id = UUID()
    var title: String
}

struct NotesSplit: View {
    @State private var notes = [Note(title: "Groceries"), Note(title: "Trip")]
    @State private var selection: Note.ID?

    var body: some View {
        NavigationSplitView {
            List(notes, selection: $selection) { note in
                Text(note.title)
            }
            .navigationTitle("Notes")
            .toolbar {
                // Acts on the list: stays with the list column.
                ToolbarItem(placement: .primaryAction) {
                    Button("New Note", systemImage: "square.and.pencil") {
                        notes.append(Note(title: "New note"))
                    }
                }
            }
        } detail: {
            if let note = notes.first(where: { $0.id == selection }) {
                Text(note.title)
                    .navigationTitle(note.title)
                    .toolbar {
                        // Acts on the open note: joins the vertical bar.
                        ToolbarItem(placement: .primaryAction) {
                            Button("Share", systemImage: "square.and.arrow.up") {}
                        }
                        ToolbarItem(placement: .bottomBar) {
                            Button("Delete", systemImage: "trash", role: .destructive) {}
                        }
                        .visibilityPriority(.low)
                    }
            } else {
                ContentUnavailableView("No Note", systemImage: "note.text")
            }
        }
    }
}
```

## Hero art under the vertical bar

```swift
import SwiftUI

struct AlbumHeader: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LinearGradient(colors: [.indigo, .teal], startPoint: .top, endPoint: .bottom)
                        .frame(height: 240)
                        .backgroundExtensionEffect()   // mirrored copies fill the area under the bar
                    Text("Tracks")
                        .font(.title2)
                        .contentMargins(for: .container, edges: .horizontal)
                }
            }
            .toolbar {
                Button("Play", systemImage: "play.fill") {}
                Button("Shuffle", systemImage: "shuffle") {}
            }
        }
    }
}
```

Use `.contentMargins(for: .container, edges: .horizontal)` instead of `.padding(.horizontal, 20)`. On iPhone Duo the margin next to the vertical bar differs from the far one ([doc](https://developer.apple.com/documentation/swiftui/contentmarginguide/container)).

## Full-screen player: a fixed opt-out

Decide once per screen. Hide the bars with `toolbarVisibility(_:for:)` when you only want them gone, and keep `toolbarVerticalBehavior(_:)` for the layout choice ([doc](https://developer.apple.com/documentation/swiftui/view/toolbarverticalbehavior(_:))).

```swift
import SwiftUI

struct PlayerScreen: View {
    @State private var controlsHidden = false

    var body: some View {
        NavigationStack {
            Color.black
                .ignoresSafeArea()
                .onTapGesture { controlsHidden.toggle() }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Back 15 Seconds", systemImage: "gobackward.15") {}
                        Button("Play", systemImage: "play.fill") {}
                        Button("Forward 15 Seconds", systemImage: "goforward.15") {}
                    }
                }
                // Fixed for this screen: video wants the full width.
                .toolbarVerticalBehavior(.disabled)
                // State only shows or hides the bars; it never flips the axis.
                .toolbarVisibility(controlsHidden ? .hidden : .visible, for: .navigationBar, .bottomBar)
        }
    }
}
```

## Sheet with only a Close button

On the outer display a sheet's toolbar goes vertical. With a single item that wastes width, so turn it off inside the sheet ([Tech Talk 111462](https://developer.apple.com/videos/play/tech-talks/111462/), [Tech Talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/)).

```swift
import SwiftUI

struct TipsButton: View {
    @State private var showsTips = false

    var body: some View {
        Button("Tips", systemImage: "lightbulb") { showsTips = true }
            .sheet(isPresented: $showsTips) {
                NavigationStack {
                    Text("Swipe left on a row to archive it.")
                        .navigationTitle("Tips")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close", systemImage: "xmark", role: .close) { showsTips = false }
                            }
                        }
                }
                .toolbarVerticalBehavior(.disabled)
            }
    }
}
```

## A custom item view that fits the vertical bar

Opt a custom view in with `.verticalPreferred` only when it fits the bar's fixed width. Read `toolbarVerticalEdge` inside the view to drop extra text when vertical bars are in play ([Tech Talk 111462](https://developer.apple.com/videos/play/tech-talks/111462/)).

```swift
import SwiftUI

struct ZoomControl: View {
    @Environment(\.toolbarVerticalEdge) private var barEdge
    @Binding var zoom: Double

    var body: some View {
        let isVertical = barEdge != nil
        let layout = isVertical ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        layout {
            Button("Zoom In", systemImage: "plus.magnifyingglass") { zoom *= 1.25 }
            if !isVertical {
                Text(zoom, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
            }
            Button("Zoom Out", systemImage: "minus.magnifyingglass") { zoom /= 1.25 }
        }
        .labelStyle(.iconOnly)
    }
}

struct MapCanvas: View {
    @State private var zoom = 1.0

    var body: some View {
        NavigationStack {
            Text("Map")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        ZoomControl(zoom: $zoom)
                    }
                    .axisBehavior(.verticalPreferred)
                }
        }
    }
}
```

## Badges instead of counts in text

```swift
import SwiftUI

struct InboxScreen: View {
    let unread: Int

    var body: some View {
        NavigationStack {
            List(0..<20, id: \.self) { Text("Message \($0)") }
                .navigationTitle("Mail")
                .toolbar {
                    // Not "Inbox (7)": a symbol with a badge fits the vertical bar.
                    ToolbarItem(placement: .bottomBar) {
                        Button("Inbox", systemImage: "tray") {}
                            .badge(unread)
                    }
                    .visibilityPriority(.high)   // status items stay visible longer
                    ToolbarItem(placement: .bottomBar) {
                        Button("Compose", systemImage: "square.and.pencil") {}
                    }
                    .visibilityPriority(ToolbarItemVisibilityPriority(higherThan: .high))
                }
        }
    }
}
```

## Sidebar with sidebar-only content

`TabSection` groups show in the sidebar. Gate extra UI on `isTabViewSidebarAvailable` ([doc](https://developer.apple.com/documentation/swiftui/environmentvalues/istabviewsidebaravailable)).

```swift
import SwiftUI

struct LibraryRoot: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") { HomeTab() }
            Tab("Search", systemImage: "magnifyingglass", role: .search) { Text("Search") }
            TabSection("Library") {
                Tab("Songs", systemImage: "music.note") { Text("Songs") }
                Tab("Albums", systemImage: "square.stack") { Text("Albums") }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .defaultTabBarPlacement(.sidebar)
    }
}

struct HomeTab: View {
    @Environment(\.isTabViewSidebarAvailable) private var hasSidebar

    var body: some View {
        NavigationStack {
            List {
                Text("Recently played")
                if !hasSidebar {
                    // The sidebar already lists these; show them here only with a tab bar.
                    NavigationLink("Songs") { Text("Songs") }
                    NavigationLink("Albums") { Text("Albums") }
                }
            }
            .navigationTitle("Home")
        }
    }
}
```

## Deployment targets below iOS 27.1

iPhone Duo always runs iOS 27.1 or later, so these fallbacks only run on other iPhones. Use the helpers instead of raw calls when the deployment target is lower. This block typechecks with deployment targets iOS 17.0, 17.5, 18.0 and 26.0.

```swift
import SwiftUI

extension View {
    /// Turns the vertical bar off on iOS 27.1 and later. Does nothing earlier.
    @ViewBuilder
    func duoHorizontalBarsOnly() -> some View {
        if #available(iOS 27.1, *) {
            toolbarVerticalBehavior(.disabled)
        } else {
            self
        }
    }

    /// Keeps toolbar items ahead of the tab bar when space runs out.
    @ViewBuilder
    func duoPrefersToolbarItems() -> some View {
        if #available(iOS 27.1, *) {
            toolbarVerticalCompressionBehavior(.prefersToolbarItems)
        } else {
            self
        }
    }

    /// Places a sheet on the trailing edge on iOS 27 and later.
    @ViewBuilder
    func duoTrailingSheet() -> some View {
        if #available(iOS 27.0, *) {
            presentationPlacement(.trailing)
        } else {
            self
        }
    }
}

extension ToolbarContent {
    /// Applies a visibility priority on iOS 27 and later.
    @ToolbarContentBuilder
    func duoPriority(high: Bool) -> some ToolbarContent {
        if #available(iOS 27.0, *) {
            visibilityPriority(high ? .high : .low)
        } else {
            self
        }
    }

    /// Keeps an item that swaps symbol and text on the horizontal axis.
    @ToolbarContentBuilder
    func duoHorizontalOnly() -> some ToolbarContent {
        if #available(iOS 27.1, *) {
            axisBehavior(.horizontalOnly)
        } else {
            self
        }
    }
}

extension ToolbarItemPlacement {
    /// Pinned trailing on iOS 27 and later, primary action before that.
    static var duoPinnedTrailing: ToolbarItemPlacement {
        if #available(iOS 27.0, *) {
            .topBarPinnedTrailing
        } else {
            .primaryAction
        }
    }
}

// Use them like the plain modifiers.
struct ComposeScreen: View {
    var body: some View {
        NavigationStack {
            Text("Draft")
                .toolbar {
                    ToolbarItem(placement: .duoPinnedTrailing) {
                        Button("Send", systemImage: "paperplane") {}
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button("Attach", systemImage: "paperclip") {}
                    }
                    .duoPriority(high: true)
                }
                .duoPrefersToolbarItems()
        }
    }
}
```
