# Smooth at 120 Hz

A fold lays out the whole window in one go, and on the inner display that window is about twice as wide. This file covers the frame budget, custom per-frame motion, and how to test. The code typechecks against the iOS 27.1 simulator SDK in Swift 5 mode, Swift 6 mode, and Swift 6 with `MainActor` as the default isolation. Nothing here has run on a real iPhone Duo.

## The numbers

- Both displays have ProMotion with an adaptive refresh rate up to 120 Hz ([iPhone Duo specs](https://www.apple.com/iphone-duo/specs/)). On iPhone, ProMotion switches between 10 and 120 Hz ([Optimizing ProMotion](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays)).
- At 120 Hz a frame lasts 8.3 ms. By default your main thread gets one frame to finish its part, and the render server gets one for its own ([Understanding hitches](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app)). Miss it and the frame is late: a hitch.
- The system drops the top rates in Low Power Mode and when the phone is hot. Core Animation can also pick a rate on its own ([Optimizing ProMotion](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays)).
- *Measured:* the iPhone Duo simulator reports `maximumFramesPerSecond` = 60 ([device facts](https://github.com/Kimeur/duology/blob/main/reference/device-facts.md#displays)). It can't show 120 Hz, and its timing says little about a device.

## What you get for free

SwiftUI animations, UIKit animations and Core Animation already run at the rate the display offers. A `.smooth` spring, a matched geometry move or a coordinator animation needs no frame-rate code. Spend your effort on the budget instead.

## Keep the resize update cheap

A fold runs `body` for every view that reads the size class or the size, then lays out the window.

- *Measured:* on Open, a full-width view went through three new widths within 50 to 250 ms: 382 → 466 → 951 → 867 pt (the safe area insets change around the resize). Every `onGeometryChange` action and `GeometryReader` that reads the width runs for each of them. Return a small value from the transform, such as a column count, so the action runs only when that value changes.
- No sorting, filtering, date or number formatting, or image decoding in `body`. Do it once when the data changes.
- Use `LazyVStack`, `LazyVGrid` or `List` for long content, so a fold lays out only what is on screen.
- Don't put a `GeometryReader` in every row. Read the size once, high up, and pass a value down.

```swift
import SwiftUI
import Observation

struct Order: Identifiable, Hashable, Sendable {
    let id: Int
    var title: String
    var total: Decimal
    var date: Date
}

struct OrderRow: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let detail: String
}

@MainActor @Observable
final class OrdersModel {
    private(set) var orders: [Order] = []
    /// Sorted and formatted once, when the data changes. A fold re-runs body; it must not redo this.
    private(set) var rows: [OrderRow] = []

    func setOrders(_ new: [Order]) {
        orders = new
        rows = new.sorted { $0.date > $1.date }.map { order in
            OrderRow(id: order.id, title: order.title, detail: order.total.formatted(.currency(code: "EUR")))
        }
    }
}

struct OrdersList: View {
    let model: OrdersModel
    var body: some View {
        List(model.rows) { row in      // no sorting, filtering or formatting here
            LabeledContent(row.title, value: row.detail)
        }
    }
}
```

## Custom per-frame motion

Only for drawing you do yourself, such as a hinge-driven effect or a game. Use a [`CADisplayLink`](https://developer.apple.com/documentation/quartzcore/cadisplaylink):

- Ask for a range with `preferredFrameRateRange`. Request 120 Hz only for large, fast movement; small or slow changes look the same at a lower rate and cost less. An animation that asks for 120 Hz and can't keep up looks worse than one that holds a steady lower rate.
- Drive the animation from `targetTimestamp`, the time the frame will appear, not from a callback count. The rate can change at any moment.
- On iPhone, Core Animation applies rates above its default only when Info.plist has `CADisableMinimumFrameDurationOnPhone` set to `YES`.

```swift
import QuartzCore
import UIKit

/// Drives a custom effect from the display's refresh, at whatever rate the system grants.
/// Above 60 Hz on iPhone it also needs CADisableMinimumFrameDurationOnPhone = YES in Info.plist.
@MainActor
final class FrameDriver {
    private var link: CADisplayLink?
    private var start: CFTimeInterval = 0
    private let duration: CFTimeInterval
    private let update: (Double) -> Void

    init(duration: CFTimeInterval, update: @escaping (Double) -> Void) {
        self.duration = duration
        self.update = update
    }

    func run() {
        stop()
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        // Large, fast movement may use up to 120 Hz. Small or slow changes don't need it.
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        start = CACurrentMediaTime()
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        // Pace by the time the frame will appear, not by counting callbacks:
        // the rate can drop at any moment (Low Power Mode, heat, other animations).
        let progress = min(1, (link.targetTimestamp - start) / duration)
        update(progress)
        if progress >= 1 { stop() }
    }
}
```

```xml
<key>CADisableMinimumFrameDurationOnPhone</key>
<true/>
```

## The hinge stream

- `onHingeChange` and `UIHingeInteraction` report the angle while the phone moves. Apple presents the hinge as a source of effects and interactions, and points to arrangements and reserved regions for layout ([Tech Talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/?time=154)).
- *Measured:* while the simulator opened, our probe's hinge updates arrived 30 to 180 ms apart. A device may report at another rate; UIKit's header says the rate and precision can change.
- Map the angle to a cheap property (an offset, an opacity, a rotation) on one view. Never run layout, a fetch or a model write per update.
- Under Reduce Motion, turn hinge-driven zoom, parallax and tilt off.

## Test it

1. **Simulator, for layout:** Device Hub > Device > Slow Animations, then press Closed, Open and Partially Open ([Device Hub](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)). Slow motion shows a pop, a jump or a control that leaves and comes back. It says nothing about frame rate.
2. **Device, for smoothness:** profile open and close with the Hitches instrument in Instruments. In the field, Xcode Organizer's Hitches metric reports a hitch rate in ms of pause per second; Apple calls 10 ms/s or less good, up to 25 ms/s a warning, and more than that critical ([Understanding hitches](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app)).
3. **Device, under stress:** repeat with Low Power Mode on. The rate drops, and pacing by `targetTimestamp` keeps custom motion at the right speed.

## Sources

- [Optimizing iPhone and iPad apps to support ProMotion displays](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays): rates, the Info.plist key, `preferredFrameRateRange`, `targetTimestamp`, Low Power Mode and heat.
- [Understanding hitches in your app](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app): the 8.3 ms budget, commit and render hitches, the Hitches metric.
- [WWDC21 Optimize for variable refresh rate displays](https://developer.apple.com/videos/play/wwdc2021/10147/): why `targetTimestamp` beats `timestamp`.
