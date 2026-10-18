# Tabs to sidebar

An app with a tab bar. Closed, the tabs stay a tab bar, on the side of the outer display. Open, the same tabs become a sidebar with room for sections and more destinations.

Prior art: Microsoft's [navigation rail](https://learn.microsoft.com/en-us/previous-versions/dual-screen/design/navigation) guidance for Surface Duo. On iPhone Duo this is a one-line API ([talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=344)).

## Use it when

- The app is dense with information and has many top-level sections. Apple's example is Health, and Apple says this option isn't for every app ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=454)).
- The sections group well (Library: Songs, Albums, Artists).

Keep the tab bar when the app has a handful of destinations that people switch between all day. A sidebar for four tabs mostly takes width away from content. (Duology's advice, not an Apple rule.)

## How it behaves

| State | What shows |
|---|---|
| Closed (outer display) | A tab bar, vertical on the side, under the status bar ([HIG, Vertical controls](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls)) |
| Open, inner display | A sidebar listing every tab, with tab sections as groups |
| Split View, half the inner display | Not measured. Check whether you get a sidebar or a tab bar. (unverified) |

What we measured on the iOS 27.1 iPhone Duo simulator, open and flat, with the recipe's setup: a sidebar showed on the leading side with Home, Browse and Search, then a collapsible "Library" group with its tabs. Inside the tabs, `isTabViewSidebarAvailable` was `true`. `tabBarPlacement` still read a bottom-bar placement, so it is not a reliable "sidebar on screen" test.

## Apple APIs

| Need | SwiftUI | UIKit | Availability |
|---|---|---|---|
| Ask for a sidebar where the bar can't switch forms | [`defaultTabBarPlacement(_:)`](https://developer.apple.com/documentation/swiftui/view/defaulttabbarplacement(_:)) with `.sidebar` | `mode = .tabSidebar` plus [`UITabBarController.Sidebar.preferredPlacement`](https://developer.apple.com/documentation/uikit/uitabbarcontroller/sidebar-swift.class/preferredplacement) = `.sidebar` | iOS 27.0 |
| The style it needs | [`.tabViewStyle(.sidebarAdaptable)`](https://developer.apple.com/documentation/swiftui/tabviewstyle/sidebaradaptable) | `UITabBarController` with a sidebar | iOS 18 |
| Groups in the sidebar | [`TabSection`](https://developer.apple.com/documentation/swiftui/tabsection) | `UITabGroup` | iOS 18 |
| Is a sidebar available here? | [`isTabViewSidebarAvailable`](https://developer.apple.com/documentation/swiftui/environmentvalues/istabviewsidebaravailable) | [`Sidebar.isAvailable`](https://developer.apple.com/documentation/uikit/uitabbarcontroller/sidebar-swift.class/isavailable) and the delegate's [`tabBarController(_:sidebarAvailabilityDidChange:)`](https://developer.apple.com/documentation/uikit/uitabbarcontroller/sidebar-swift.class/delegate-swift.protocol/tabbarcontroller(_:sidebaravailabilitydidchange:)) | iOS 27.0 |

Apple's doc for `defaultTabBarPlacement(_:)` says it only works with the `sidebarAdaptable` style and has no effect on iPad, where people can switch between the two forms themselves. `isTabViewSidebarAvailable` is only meaningful inside the tab view's content; above the `TabView` it reads `false`.

## Rules

1. Use `.tabViewStyle(.sidebarAdaptable)` and `.defaultTabBarPlacement(.sidebar)` together. The second does nothing without the first.
2. Keep the same destinations closed and open. A section is a sidebar group; check on the closed phone that every tab inside it is still reachable from the tab bar. We have not measured how the closed tab bar shows sections. (unverified) The HIG asks for the same functionality on both displays ([HIG, Best practices](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Best-practices)).
3. Keep the selected tab through fold and unfold. Bind `TabView(selection:)` to `@SceneStorage`.
4. Hide shortcuts that repeat the sidebar, using `isTabViewSidebarAvailable`. Don't remove features with it.
5. Give every tab a title and a symbol. The vertical tab bar uses symbols, the sidebar uses both.
6. Decide what gives way when the side bar runs out of room: toolbar items (navigation-focused apps, the default) or the tab bar (task-focused apps). Set it with `toolbarVerticalCompressionBehavior(_:)`; see the `duo-navigation` skill ([HIG, Vertical controls](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls)).
7. Gate the iOS 27.0 modifier with `if #available` if you still support iOS 26.

## Recipe

Self-contained. Typechecks against the iOS 27.1 simulator SDK, also with an iOS 26 deployment target.

```swift
import SwiftUI

enum LibrarySection: String, Hashable {
    case home, browse, songs, albums, artists, search
}

struct LibraryTabs: View {
    // Same tab selected after fold, unfold and relaunch.
    @SceneStorage("library.tab") private var selection = LibrarySection.home

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: LibrarySection.home) {
                HomeScreen()
            }
            Tab("Browse", systemImage: "square.grid.2x2", value: LibrarySection.browse) {
                Text("Browse")
            }
            // Sections group tabs in the sidebar. Check how the closed tab bar shows them.
            TabSection("Library") {
                Tab("Songs", systemImage: "music.note", value: LibrarySection.songs) {
                    Text("Songs")
                }
                Tab("Albums", systemImage: "square.stack", value: LibrarySection.albums) {
                    Text("Albums")
                }
                Tab("Artists", systemImage: "music.mic", value: LibrarySection.artists) {
                    Text("Artists")
                }
            }
            Tab(value: LibrarySection.search, role: .search) {
                Text("Search")
            }
        }
        // Required: defaultTabBarPlacement only acts on this style.
        .tabViewStyle(.sidebarAdaptable)
        .sidebarWhereAvailable()
    }
}

extension View {
    /// Asks for a sidebar where the bar can't switch between forms (iPhone Duo's
    /// inner display). Earlier systems keep their tab bar.
    @ViewBuilder
    func sidebarWhereAvailable() -> some View {
        if #available(iOS 27.0, *) {
            defaultTabBarPlacement(.sidebar)
        } else {
            self
        }
    }
}

struct HomeScreen: View {
    var body: some View {
        NavigationStack {
            List {
                if #available(iOS 27.0, *) {
                    LibraryShortcuts()
                }
                Text("Recently played")
            }
            .navigationTitle("Home")
        }
    }
}

/// Shortcuts that repeat the Library tabs. Hide them when the sidebar already lists them.
@available(iOS 27.0, *)
struct LibraryShortcuts: View {
    @Environment(\.isTabViewSidebarAvailable) private var sidebarAvailable

    var body: some View {
        if !sidebarAvailable {
            Section("Library") {
                Label("Songs", systemImage: "music.note")
                Label("Albums", systemImage: "square.stack")
            }
        }
    }
}
```

UIKit: set `tabBarController.mode = .tabSidebar` and `tabBarController.sidebar.preferredPlacement = .sidebar` (iOS 27.0). *Measured* by `duo-navigation`'s probe on the open simulator: `preferredPlacement` alone gave no sidebar. Group tabs with `UITabGroup`, and listen for `tabBarController(_:sidebarAvailabilityDidChange:)` instead of checking the device.

## Pitfalls

- **`defaultTabBarPlacement` without `sidebarAdaptable`.** Compiles, does nothing.
- **Different sections per display.** A tab that exists only in the sidebar disappears when the phone closes.
- **Testing `tabBarPlacement` to detect the sidebar.** We measured a bottom-bar value while the sidebar was on screen.
- **Branching on the device.** `userInterfaceIdiom` or "is this a Duo" checks break on iPad, Mac and future devices. The placement API already knows where a sidebar makes sense.
- **A sidebar next to a sidebar.** A `NavigationSplitView` inside a tab adds a second leading column next to the tab sidebar and squeezes the content. Prefer a `NavigationStack` in tabs, or test the width you have left. (design advice, not an Apple rule)

## Test it

1. Closed: a tab bar on the side. Every Library tab is reachable.
2. Pick Albums. Open: the sidebar shows with Albums selected.
3. Open: the Library shortcuts on Home are gone. Close: they come back.
4. Split View: note whether you get a sidebar or a tab bar, and that both work.
5. Outer display, landscape, with a long toolbar: the compression behaviour you chose wins.

## Gallery screen

[`samples/DuologyGallery/DuologyGallery/Patterns/TabsToSidebarView.swift`](https://github.com/Kimeur/duology/blob/main/samples/DuologyGallery/DuologyGallery/Patterns/TabsToSidebarView.swift)

## Sources

IDs point to [`reference/sources.md`](https://github.com/Kimeur/duology/blob/main/reference/sources.md): D1 (hub), D2 (HIG), V1 (talk 111461), V2 (talk 111462), V6 (talk 111466). Prior art: Microsoft's [navigation rail](https://learn.microsoft.com/en-us/previous-versions/dual-screen/design/navigation) page.
