# Live Activities on iPhone Duo

A full Live Activity that reads well in the vertical Dynamic Island, on the Lock Screen and in StandBy, with previews. What Apple says, what it hasn't said, and what we saw: [evidence.md](evidence.md).

## What changes on Duo

| Presentation | On iPhone Duo | Source |
|---|---|---|
| Compact (leading and trailing) | Drawn narrower; `isDynamicIslandLimitedInWidth` tells your view when. | [doc](https://developer.apple.com/documentation/swiftui/environmentvalues/isdynamicislandlimitedinwidth) names iPhone Duo |
| Minimal | Drawn narrower, same value | same doc |
| Several activities | On iPhone the island shows up to three as minimal views, beside the island. On Duo the island grows down the side column as activities arrive. How several stack there: not published. | [HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities), [Tech Talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=104) |
| Expanded | Shown when people touch and hold. Its layout in a vertical island: not published. | HIG |
| Lock Screen | As on any iPhone. Duo's Lock Screen controls sit on the side. | [Newsroom](https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/) |
| StandBy | On either display, even when not charging. The activity shows as the minimal view; a tap shows the Lock Screen view scaled up 2x. | Newsroom; [HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities#StandBy) |

The HIG's limited-width guidance (13 October 2026) asks for compact and minimal views that fit a 28 pt circle: a short number, an abbreviation or a symbol, not a sentence. When your design can't give both compact views a limited form, keep only the leading view: the system hides an empty trailing view ([HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities)).

## The code

```swift
import ActivityKit
import SwiftUI
import WidgetKit

struct DeliveryAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var minutesLeft: Int
        var stage: String
    }
    var orderName: String
}

struct DeliveryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeliveryAttributes.self) { context in
            // Lock Screen, and StandBy after a tap (scaled up).
            DeliveryLockScreenView(state: context.state, orderName: context.attributes.orderName)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.orderName, systemImage: "bag.fill")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.minutesLeft) min").monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.stage)
                }
            } compactLeading: {
                Image(systemName: "bag.fill")
            } compactTrailing: {
                MinutesLeft(minutes: context.state.minutesLeft)
            } minimal: {
                MinutesLeft(minutes: context.state.minutesLeft)
            }
            .widgetURL(URL(string: "shop://orders/current"))
        }
    }
}

/// Reads the environment and picks the form. Narrow on iPhone Duo and on iPhone held sideways.
struct MinutesLeft: View {
    let minutes: Int

    var body: some View {
        if #available(iOS 27.0, *) {
            LimitedAware(minutes: minutes)
        } else {
            MinutesLeftLabel(minutes: minutes, limited: false)
        }
    }

    @available(iOS 27.0, *)
    private struct LimitedAware: View {
        let minutes: Int
        @Environment(\.isDynamicIslandLimitedInWidth) private var isLimited

        var body: some View {
            MinutesLeftLabel(minutes: minutes, limited: isLimited)
        }
    }
}

/// The two forms, as a plain view you can preview side by side.
struct MinutesLeftLabel: View {
    let minutes: Int
    let limited: Bool

    var body: some View {
        if limited {
            // Fits a 28 pt circle: the number alone.
            Text("\(minutes)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
        } else {
            Text("\(minutes) min")
                .monospacedDigit()
        }
    }
}

/// Lock Screen view. In StandBy the system shows it scaled up, without the widget container background.
struct DeliveryLockScreenView: View {
    let state: DeliveryAttributes.ContentState
    let orderName: String
    @Environment(\.showsWidgetContainerBackground) private var showsBackground

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(orderName).font(.headline)
            Text(state.stage)
            Text("\(state.minutesLeft) min").font(.title.bold()).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            if showsBackground {      // true on the Lock Screen
                LinearGradient(colors: [.indigo, .blue], startPoint: .top, endPoint: .bottom)
            }
        }
        .activityBackgroundTint(.indigo)   // fills the screen edge to edge in StandBy
    }
}
```

Why it is built this way:

- `isDynamicIslandLimitedInWidth` is iOS 27 only and read-only. The `#available` check keeps the extension building for older iOS. Splitting the reading view from `MinutesLeftLabel` lets you preview both forms, because you can't set the value in a preview.
- The compact leading view is one symbol, so it already fits the limited width. The trailing and minimal views carry the number.
- The Lock Screen view draws its gradient only when `showsWidgetContainerBackground` is `true`. Elsewhere, StandBy included, `activityBackgroundTint(_:)` paints the background edge to edge ([session 223](https://developer.apple.com/videos/play/wwdc2026/223/?time=679)).
- `widgetURL(_:)` sends a tap to the app. See [Opening the app](#opening-the-app).

## Previews

```swift
import SwiftUI
import WidgetKit

// requires: DeliveryAttributes, DeliveryLiveActivity, MinutesLeftLabel (above)

#Preview("Island, compact", as: .dynamicIsland(.compact), using: DeliveryAttributes(orderName: "Lunch")) {
    DeliveryLiveActivity()
} contentStates: {
    DeliveryAttributes.ContentState(minutesLeft: 12, stage: "On the way")
    DeliveryAttributes.ContentState(minutesLeft: 3, stage: "Nearly there")
}

#Preview("Island, minimal", as: .dynamicIsland(.minimal), using: DeliveryAttributes(orderName: "Lunch")) {
    DeliveryLiveActivity()
} contentStates: {
    DeliveryAttributes.ContentState(minutesLeft: 12, stage: "On the way")
}

#Preview("Lock Screen", as: .content, using: DeliveryAttributes(orderName: "Lunch")) {
    DeliveryLiveActivity()
} contentStates: {
    DeliveryAttributes.ContentState(minutesLeft: 12, stage: "On the way")
}

#Preview("Limited width, both forms") {
    HStack(spacing: 24) {
        MinutesLeftLabel(minutes: 12, limited: true)
            .frame(width: 28, height: 28)
            .background(.black, in: .circle)
            .foregroundStyle(.white)
        MinutesLeftLabel(minutes: 12, limited: false)
    }
    .padding()
}
```

The island previews show an iPhone island, not Duo's vertical one. The last preview is the check that matters on Duo: does the limited form read inside 28 pt, at your largest Dynamic Type size?

## Opening the app

A tap on the activity opens your app on the display the person is using: the outer display when the phone is closed, the inner display when it is open. The deep link must work in both layouts. Route it to state that both layouts read, not to a view that exists in one of them (`duo-continuity`):

```swift
import SwiftUI

/// The app side of a widget or Live Activity tap. The tap opens the app on whichever display is in use,
/// so route to state that both layouts read, not to a screen.
@Observable
final class Router {
    var selectedTab = "home"
    var showsCurrentOrder = false

    func open(_ url: URL) {
        switch url.host() {
        case "orders": selectedTab = "orders"; showsCurrentOrder = true
        case "shelf": selectedTab = "library"
        default: break
        }
    }
}

struct RootView: View {
    @State private var router = Router()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Home", systemImage: "house", value: "home") { Text("Home") }
            Tab("Library", systemImage: "books.vertical", value: "library") { Text("Library") }
            Tab("Orders", systemImage: "bag", value: "orders") {
                Text(router.showsCurrentOrder ? "Current order" : "Orders")
            }
        }
        .onOpenURL { router.open($0) }
    }
}
```

## Duology advice, not Apple's

- End the activity as soon as the task ends. On Duo every running activity takes height from the side column, which every app's vertical bar shares (*measured* about 84 pt closed and 94 pt open for one activity, [evidence.md](evidence.md#the-island-in-the-side-column)).
- Don't put a control people must use only in the expanded view. Its form on Duo is not published; keep the same action on the Lock Screen view.

## Testing

- The iPhone Duo simulator starts activities, but it did not draw the island's content in our runs. Most app extensions can't run there ([Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)).
- Use the previews above for the views, and a real iPhone Duo for the vertical island, the expanded view and StandBy on both displays. Mark anything you couldn't check as untested.
