# Widgets and controls on iPhone Duo

Widget families, a widget that fills whatever size it gets, and a control for Control Center and the Lock Screen. What Apple has and hasn't said for Duo is in [SKILL.md](../SKILL.md); what we saw in the simulator is in [evidence.md](evidence.md).

## Where widgets appear on Duo

- Closed: the outer display's Home Screen. Its Dock sits in the side column ([Newsroom](https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/); *measured*, [evidence.md](evidence.md#home-screen)).
- Open: two Home Screen pages side by side, with Today View, a scrolling list of widgets, on the left (Newsroom).
- StandBy, on either display (Newsroom). On iPhone, StandBy shows two small widgets side by side, scaled up, without their background, and tints them red in low light ([HIG: Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets#StandBy-and-CarPlay)).
- The Lock Screen, for accessory families.

## Families and what Apple says about each

| Family | iPhone, per the HIG table | Notes |
|---|---|---|
| `systemSmall` | Home Screen, Today View, StandBy, CarPlay, Apple HomeView | The StandBy family |
| `systemMedium`, `systemLarge` | Home Screen, Today View | |
| `systemExtraLarge` | Not supported | |
| `systemExtraLargePortrait` (iOS 27.0) | Not supported | The API doc says it can appear on the Home Screen on iOS and in Today View; WWDC26 session 277 says it is new on iOS 27 |
| `accessoryCircular`, `accessoryRectangular`, `accessoryInline` | Lock Screen | |

Sources: [HIG: Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets), [systemExtraLargePortrait](https://developer.apple.com/documentation/widgetkit/widgetfamily/systemextralargeportrait), [session 277](https://developer.apple.com/videos/play/wwdc2026/277/?time=711).

The HIG table and the API doc disagree on the tall family. Neither mentions Duo. Offer it behind `#available(iOS 27.0, *)`; if Duo doesn't offer it, nothing breaks.

The HIG lists widget sizes in points for ten iPhone screen sizes. None of them is a Duo display. `WidgetFamily` warns that sizes vary by device and asks for flexible content ([doc](https://developer.apple.com/documentation/widgetkit/widgetfamily)). So read the space you get; never branch on a size.

## A widget that grows by rows

```swift
import SwiftUI
import WidgetKit

struct ShelfEntry: TimelineEntry {
    let date: Date
    let titles: [String]
}

struct ShelfProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShelfEntry {
        ShelfEntry(date: .now, titles: ["The Map", "Tide Tables", "Kelp", "Rock Pools", "Night Ferry"])
    }

    func getSnapshot(in context: Context, completion: @escaping (ShelfEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShelfEntry>) -> Void) {
        completion(Timeline(entries: [placeholder(in: context)], policy: .atEnd))
    }
}

struct ShelfWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "shelf", provider: ShelfProvider()) { entry in
            ShelfWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "reader://shelf"))
        }
        .configurationDisplayName("Reading shelf")
        .description("The books you are reading.")
        .supportedFamilies(Self.families)
    }

    static var families: [WidgetFamily] {
        var list: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular]
        if #available(iOS 27.0, *) {
            list.append(.systemExtraLargePortrait)   // new tall family; whether iPhone Duo offers it is unverified
        }
        return list
    }
}

struct ShelfWidgetView: View {
    let entry: ShelfEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall, .accessoryRectangular:
            Text(entry.titles.first ?? "Nothing to read")
                .font(.headline)
                .minimumScaleFactor(0.7)
        case .systemMedium:
            ViewThatFits(in: .vertical) {
                list(limit: 3)
                list(limit: 2)
            }
        default:
            // Large and the tall family: as many rows as fit, never a fixed height.
            ViewThatFits(in: .vertical) {
                list(limit: 10)
                list(limit: 6)
                list(limit: 3)
            }
        }
    }

    private func list(limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(entry.titles.prefix(limit), id: \.self) { Text($0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- `ViewThatFits` picks the longest list that fits, so the same family shows more rows where the system gives it more height.
- The background is removable by default, so the small family can appear in StandBy. Don't pass `false` to `containerBackgroundRemovable(_:)` unless you accept losing StandBy ([HIG](https://developer.apple.com/design/human-interface-guidelines/widgets#StandBy-and-CarPlay)).
- One design for both displays. Nothing in WidgetKit tells a widget which display it is on.

Previews, one per family you support:

```swift
import SwiftUI
import WidgetKit

// requires: ShelfWidget, ShelfEntry (above)

#Preview("Shelf, small", as: .systemSmall) {
    ShelfWidget()
} timeline: {
    ShelfEntry(date: .now, titles: ["The Map", "Tide Tables"])
}

#Preview("Shelf, large", as: .systemLarge) {
    ShelfWidget()
} timeline: {
    ShelfEntry(date: .now, titles: ["The Map", "Tide Tables", "Kelp", "Rock Pools", "Night Ferry"])
}
```

## Controls

A control sits in Control Center, on the Lock Screen, or on the Action button ([HIG: Controls](https://developer.apple.com/design/human-interface-guidelines/controls)). On Duo, Lock Screen controls sit on the side (Newsroom). The spec page lists volume buttons, Camera Control and a side button, and no Action button ([specs](https://www.apple.com/iphone-duo/specs/)). The Controls page has not changed since June 2024 and says nothing about Duo.

```swift
import AppIntents
import SwiftUI
import WidgetKit

nonisolated enum FocusTimer {
    /// Shared with the app through an App Group.
    static var isRunning: Bool {
        get { UserDefaults(suiteName: "group.com.example.focus")?.bool(forKey: "running") ?? false }
        set { UserDefaults(suiteName: "group.com.example.focus")?.set(newValue, forKey: "running") }
    }
}

struct SetFocusTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Focus timer"

    @Parameter(title: "Running")
    var value: Bool

    func perform() async throws -> some IntentResult {
        FocusTimer.isRunning = value
        return .result()
    }
}

struct FocusTimerControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.example.focus-timer") {
            ControlWidgetToggle(isOn: FocusTimer.isRunning, action: SetFocusTimerIntent()) {
                Label("Focus timer", systemImage: "timer")
            } valueLabel: { isOn in
                Text(isOn ? "Running" : "Off")
            }
        }
        .displayName("Focus timer")
    }
}
```

- `nonisolated` keeps the shared state usable from the intent's `perform()` in a target with MainActor default isolation (*measured*: without it, Swift 6 reports that the main actor-isolated property can't be mutated from a nonisolated context).
- Give the control a symbol that reads alone: the Lock Screen shows only the symbol.
- Don't write help text that tells Duo owners to put the control on the Action button.

## The widget bundle

```swift
import SwiftUI
import WidgetKit

// requires: ShelfWidget, FocusTimerControl (above), DeliveryLiveActivity (live-activities.md)

@main
struct ExampleWidgets: WidgetBundle {
    var body: some Widget {
        ShelfWidget()
        DeliveryLiveActivity()
        FocusTimerControl()
    }
}
```

## Testing

- The iPhone Duo simulator can't run most app extensions ([Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)). Use Xcode Previews for each family.
- On a device, add each family to the outer Home Screen, both inner pages and Today View, and the small family to StandBy on both displays. Then open the app from each and check that it lands on the right item, closed and open.
