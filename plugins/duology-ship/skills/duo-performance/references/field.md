# From real users: hitches and hangs per pose

iOS 27 MetricKit can split its daily report by a state your app reports through the StateReporting framework. Report the pose, and the report gives hitch time, hang time and your signpost intervals for each pose, from people's phones. Sources: [MetricManager](https://developer.apple.com/documentation/metrickit/metricmanager), [init(enabledStateReportingDomains:)](https://developer.apple.com/documentation/metrickit/metricmanager/init(enabledstatereportingdomains:)), [MetricReport](https://developer.apple.com/documentation/metrickit/metricreport), [StateReporting](https://developer.apple.com/documentation/statereporting), [StateReporter](https://developer.apple.com/documentation/statereporting/statereporter) (all iOS 27.0).

The code typechecks against the iOS 27.1 simulator SDK in Swift 5 mode, Swift 6 mode, and Swift 6 with `MainActor` as the default isolation (6 November 2026). The first three blocks also built and ran in an app with an iOS 26.0 deployment target.

## What Apple's documentation says

- `MetricManager` is a class you create and keep; share one instance. Reports arrive through `metricReports`, an `AsyncSequence` that never throws.
- `MetricManager(enabledStateReportingDomains:)` turns on per-state metrics. Each report then fills `stateEntries`, one per recorded state, besides the usual `intervalEntries`.
- Only some metrics appear per state: hang time, hitch time, app termination counts, signpost intervals and app runtime. CPU time, memory, network, disk, GPU and launch metrics appear only for the whole interval.
- `StateReporter.reporter(for:)` returns one object per domain; use a reverse-DNS domain string. `reportTransition(to:)` starts a state; reporting the same label again does nothing; `nil` means no state. Reporting more often than "user interaction timescales" can be rate-limited.
- Each report covers 24 hours.
- `MetricManager.logHandle(category:)` and `mxSignpost` mark your own intervals; `mxSignpostAnimationIntervalBegin` marks an animation interval, and the report's `SignpostIntervalMetric` then carries `hitchTimeRatio`, `totalHitchTime` and `totalAnimationTime` (from the iOS 27.1 SDK's MetricKit interface).

## The pose, as a state

```swift
import CoreGraphics

/// The label MetricKit groups field metrics by. Pure, so it can be tested on the Mac.
nonisolated enum PoseState: String, Sendable {
    case closed, open, book, tabletop

    /// fold: the fold's frame in the view when one splits it, and whether the phone is partly folded.
    init(fold: CGRect?, isActive: Bool) {
        guard let fold else {
            self = .closed
            return
        }
        if isActive {
            self = fold.height > fold.width ? .book : .tabletop
        } else {
            self = .open
        }
    }
}
```

Read the fold from the root view's `.division` reserved regions, including inactive ones, so a flat inner display still has its fold (see `duo-postures`; the recipes' `FoldGeometry` does the same):

```swift
import SwiftUI

extension View {
    /// Calls action with the pose now and when it changes. Before iOS 27.1, never.
    func onPoseChange(_ action: @escaping (PoseState) -> Void) -> some View {
        modifier(PoseReader(action: action))
    }
}

private struct PoseReader: ViewModifier {
    let action: (PoseState) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onGeometryChange(for: PoseState.self) { proxy in
                let size = proxy.size
                let regions = proxy.reservedRegions(kind: .division, options: .includeInactive)
                // Only a fold that splits the view in two counts.
                let fold = regions.first { region in
                    let f = region.frame
                    return f.height > f.width ? (f.minX > 0 && f.maxX < size.width)
                                              : (f.minY > 0 && f.maxY < size.height)
                }
                return PoseState(fold: fold?.frame, isActive: fold?.isActive ?? false)
            } action: { pose in
                action(pose)
            }
        } else {
            content
        }
    }
}
```

## Reporting it

```swift
import Foundation
import MetricKit
import StateReporting
import os

/// Tells MetricKit the pose, so its daily report splits hitch and hang time by pose,
/// and marks each fold as an animation interval, so it counts hitches during folds.
/// Does nothing before iOS 27.
@MainActor
final class FoldMetrics {
    private let sink: AnyObject?
    private var settle: Task<Void, Never>?
    private var folding = false
    private var reported: PoseState?

    /// domain: reverse DNS, for example "com.example.myapp.pose".
    init(domain: String) {
        if #available(iOS 27.0, *) {
            sink = MetricKitSink(domain: domain)
        } else {
            sink = nil
        }
    }

    /// Call with every pose change. The first change of a fold opens the interval. The
    /// pose is reported once it has held for half a second: one fold passes through
    /// several sizes, and reporting each step could be rate-limited.
    func poseChanged(to pose: PoseState) {
        guard #available(iOS 27.0, *), let sink = sink as? MetricKitSink else { return }
        if !folding {
            folding = true
            sink.beginFold()
        }
        settle?.cancel()
        settle = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            self.folding = false
            sink.endFold()
            if self.reported != pose {
                self.reported = pose
                sink.report(pose)
            }
        }
    }
}

@available(iOS 27.0, *)
@MainActor
private final class MetricKitSink {
    let manager: MetricManager
    let reporter: StateReporter<Never, Never>
    let foldLog = MetricManager.logHandle(category: "Fold")

    init(domain: String) {
        manager = MetricManager(enabledStateReportingDomains: [StateReportingDomain(rawValue: domain)])
        reporter = StateReporter<Never, Never>.reporter(for: domain)
        let manager = manager
        Task.detached {
            // About once a day, on a device. Keep what you need: here, hitch time per pose.
            for await report in manager.metricReports {
                for entry in report.stateEntries where entry.state.domain == domain {
                    for case .hitchTime(let hitches) in entry.values {
                        Logger(subsystem: "com.example.myapp", category: "Metrics")
                            .info("\(entry.state.label, privacy: .public): \(hitches.ratio.description, privacy: .public)")
                    }
                }
            }
        }
    }

    func beginFold() { mxSignpostAnimationIntervalBegin(log: foldLog, name: "Fold") }
    func endFold() { mxSignpost(.end, log: foldLog, name: "Fold") }
    func report(_ pose: PoseState) { reporter.reportTransition(to: pose.rawValue) }
}
```

Create it once, in the App, and hook it to the root view. Apple asks for one `MetricManager` per app, and a `@State` value in a view is created again each time that view is initialized:

```swift
import SwiftUI

@main
struct MyApp: App {
    @State private var metrics = FoldMetrics(domain: "com.example.myapp.pose")

    var body: some Scene {
        WindowGroup {
            Text("Content")
                .onPoseChange { metrics.poseChanged(to: $0) }
        }
    }
}
```

Send the parts of the report you need to your own analytics, or log them, and compare `open` with `closed`: a pose with more hitch time per second than the others is the one to profile on a device. The fold interval ends half a second after the last change, so read its hitch time (`totalHitchTime`) rather than its duration.

## What we measured on the simulator

On 6 November 2026, with the first three blocks above in a test app, recorded with Instruments' Points of Interest and os_signpost instruments while `duo-pose` set open, book, tabletop and closed:

- The State Reporting track showed one interval per pose, labelled `open`, `book` and `tabletop` in turn. On the way from tabletop to closed, the simulator passed through `book` and `tabletop` again for about 2 s each before `closed`; those were real poses for longer than the half-second wait, so they were reported.
- The `Fold` intervals from `MetricManager.logHandle(category:)` didn't appear in the trace, while the app's own `OSSignposter` events did. Check them on a device.
- No MetricKit report arrives on the simulator. The per-pose split in a real report is *unverified* until a device has run the app for a day.

In Xcode Organizer, the Hitches and Hangs metrics show the same app across all poses, from users who share analytics with developers.
