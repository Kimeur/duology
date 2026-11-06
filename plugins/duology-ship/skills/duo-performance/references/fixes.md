# Fixes

Code for each fix in SKILL.md, Step 3. Every block typechecks against the iOS 27.1 simulator SDK in Swift 5 mode, Swift 6 mode, and Swift 6 with `MainActor` as the default isolation (6 November 2026). The `Ledger` measurements are from the eval fixture before and after these fixes ([evidence](evidence.md#ledger-before-and-after)).

## Work once, in a model

A fold reruns `body` at each resize step. Sort, group, sum and format when the data changes, and let `body` read the result.

```swift
import Foundation
import Observation

struct Entry: Identifiable, Hashable, Sendable {
    let id: Int
    let payee: String
    let category: String
    let amount: Decimal
    let date: Date
}

@MainActor @Observable
final class LedgerModel {
    struct Row: Identifiable, Hashable, Sendable {
        let id: Int
        let payee: String
        let date: String
        let amount: String
    }

    private(set) var rows: [Row] = []
    private(set) var total: Decimal = 0

    /// Called when the entries change, never from body.
    func set(_ entries: [Entry]) {
        rows = entries.sorted { $0.date > $1.date }.map { entry in
            Row(id: entry.id,
                payee: entry.payee,
                date: entry.date.formatted(date: .abbreviated, time: .omitted),
                amount: entry.amount.formatted(.currency(code: "EUR")))
        }
        total = entries.reduce(Decimal(0)) { $0 + $1.amount }
    }
}
```

`Text(value, format:)` for one value in `body` is fine. Creating a `DateFormatter` or `NumberFormatter` in `body`, or formatting thousands of values there, is not: in `Ledger`, every row made two formatters at every resize step.

## Read the size once, as a small value

Read the size at the top of the screen and keep only what the layout needs. `onGeometryChange` calls its action only when the returned value changes: return a Boolean or a column count, not the size, and one fold runs the action once instead of at every step.

```swift
import SwiftUI

struct GridScreen: View {
    let items: [String]
    @State private var columns = 1

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns)) {
                ForEach(items, id: \.self) { Text($0) }
            }
        }
        // 382 pt closed -> 1 column; 867 pt open -> 4. Same value, no action.
        .onGeometryChange(for: Int.self) { proxy in
            max(1, Int(proxy.size.width / 200))
        } action: { columns = $0 }
    }
}
```

Not a `GeometryReader` per row: each one is laid out again at every step, and a `GeometryReader` takes all the space offered, which changes the row's own layout.

## One layout that changes shape

An `if` that builds the list in both branches makes a new list at every pose change: its scroll position, selection and state go, and the new one is laid out from scratch. `.id(width)` does the same at every resize step. Keep one list and let the layout change around it ([AnyLayout](https://developer.apple.com/documentation/swiftui/anylayout)).

```swift
import SwiftUI

struct LedgerScreen: View {
    let rows: [String]
    let total: String
    @State private var wide = false

    var body: some View {
        let layout = wide ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
        layout {
            if !wide {
                Text(total).font(.largeTitle.bold())
            }
            List(rows, id: \.self) { Text($0) }   // one list, in the same place, in every pose
            if wide {
                Text(total).font(.largeTitle.bold()).frame(maxWidth: 320)
            }
        }
        .onGeometryChange(for: Bool.self) { $0.size.width > 700 } action: { wide = $0 }
    }
}
```

For a split that must keep both panes' identity and put the fold between them, use a custom `Layout` (see `duo-layout`; the recipes' `PaneSplit` is one).

## Lazy rows

`List`, `LazyVStack` and `LazyVGrid` lay out the rows on screen. A `VStack` in a `ScrollView` lays out every row at every resize step: in `Ledger`, 2,000 rows, each with its own `GeometryReader` and two formatters.

```swift
import SwiftUI

struct Rows: View {
    let rows: [String]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(rows, id: \.self) { row in
                    Text(row).frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    Divider()
                }
            }
        }
    }
}
```

## Work that follows a fold

A prefetch or a reload for a new column count belongs after the fold, not in it. `.task(id:)` cancels the previous run when the value changes, so a short wait lets the fold's steps pass, and the work runs once for the size it ends on. Do the heavy part off the main actor.

```swift
import SwiftUI

struct Thumbnail: Sendable, Identifiable {
    let id: Int
    let pixels: Int
}

@MainActor @Observable
final class GalleryModel {
    private(set) var thumbnails: [Thumbnail] = []

    func prepare(columns: Int) async {
        let made = await Self.make(count: columns * 20, pixels: 1200 / columns)
        thumbnails = made
    }

    /// Off the main actor, whatever the module's default isolation.
    @concurrent
    nonisolated static func make(count: Int, pixels: Int) async -> [Thumbnail] {
        (0..<count).map { Thumbnail(id: $0, pixels: pixels) }
    }
}

struct Gallery: View {
    @State private var model = GalleryModel()
    @State private var columns = 1

    var body: some View {
        Text("\(model.thumbnails.count) thumbnails")
            .onGeometryChange(for: Int.self) { max(1, Int($0.size.width / 200)) } action: { columns = $0 }
            .task(id: columns) {
                // The fold's steps arrive within about 250 ms; act on the size it settles on.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await model.prepare(columns: columns)
            }
    }
}
```

## Images: decode once, for the largest display

Decoding an image at the size a view has now means decoding again when the fold changes that size. Decode once, at the largest size the image will be shown in any pose (the inner display is 2007 × 2853 px), off the main actor, and let the view scale it. ImageIO makes a thumbnail of a given size from the file ([CGImageSourceCreateThumbnailAtIndex](https://developer.apple.com/documentation/imageio/cgimagesourcecreatethumbnailatindex(_:_:_:)), [kCGImageSourceThumbnailMaxPixelSize](https://developer.apple.com/documentation/imageio/kcgimagesourcethumbnailmaxpixelsize)). *Unverified* on Duo: we didn't measure image decoding during a fold.

```swift
import ImageIO
import SwiftUI

enum Images {
    /// A decoded image no larger than maxPixels on its long side. Off the main actor.
    @concurrent
    nonisolated static func decoded(_ url: URL, maxPixels: Int) async -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

struct Cover: View {
    let url: URL
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1).resizable().scaledToFill()   // scaled, not decoded again
            } else {
                Color.secondary.opacity(0.2)
            }
        }
        .task(id: url) {
            image = await Images.decoded(url, maxPixels: 2853)
        }
    }
}
```

Size the thumbnail for where it shows: a cover that takes half the open phone needs about half of 2853 px, a grid cell much less.

## Mark your own work

An `OSSignposter` interval shows your work next to the fold in the os_signpost instrument, and in a `duo-fold-cost` trace.

```swift
import os

enum Signposts {
    static let work = OSSignposter(subsystem: "com.example.myapp", category: "Work")
}

func rebuildRows(count: Int) -> [Int] {
    let state = Signposts.work.beginInterval("Rebuild rows")
    defer { Signposts.work.endInterval("Rebuild rows", state) }
    return (0..<count).map { $0 * 2 }
}
```

## A Mac test for the work you moved

The work moved out of `body` is where a regression comes back. Time it in a test: it runs on the Mac or the simulator, with no fold.

```swift
import XCTest

nonisolated final class RowBuildingTests: XCTestCase {   // nonisolated: test targets may default to MainActor
    func testBuildingTwoThousandRowsStaysFast() {
        let dates = (0..<2_000).map { Date(timeIntervalSince1970: Double($0) * 86_400) }
        measure(metrics: [XCTClockMetric()]) {
            _ = dates.sorted(by: >).map { $0.formatted(date: .abbreviated, time: .omitted) }
        }
    }
}
```

Set a baseline in Xcode's test report once it's stable; the test then fails when the time grows past it.
