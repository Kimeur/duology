# Target audit

Depth for [`../SKILL.md`](../SKILL.md), section 4. Two ways to find controls that are too small, on the fold or out of reach: a debug modifier that logs from the running app, and a screenshot review.

## Log small targets and targets on the fold

Attach `auditTarget(_:)` to each custom control while you lay out a screen. In debug builds it prints a line for any control under 44 pt on either side, and for any control that touches an active fold.

```swift
import SwiftUI

/// What the audit learned about one control.
@available(iOS 27.1, *)
nonisolated struct TargetReport: Equatable, Sendable {
    var size: CGSize
    var touchesFold: Bool
}

@available(iOS 27.1, *)
extension View {
    /// Debug check: logs a control smaller than 44 x 44 pt or touching an active fold.
    func auditTarget(_ name: String) -> some View {
        onGeometryChange(for: TargetReport.self) { proxy in
            let bounds = CGRect(origin: .zero, size: proxy.size)
            // Default query: active folds only. Frames come in this view's own coordinates.
            let folds = proxy.reservedRegions(kind: .division)
            return TargetReport(size: proxy.size,
                                touchesFold: folds.contains { $0.frame.intersects(bounds) })
        } action: { report in
            #if DEBUG
            if report.size.width < 44 || report.size.height < 44 {
                print("TARGET \(name): \(Int(report.size.width)) x \(Int(report.size.height)) pt, under 44 pt")
            }
            if report.touchesFold { print("TARGET \(name): touches the fold") }
            #endif
        }
    }
}
```

Use it like this, then switch poses in Device Hub and read the console:

```swift
import SwiftUI

// requires: TargetReport, auditTarget(_:) (above)

@available(iOS 27.1, *)
struct RecorderControls: View {
    var body: some View {
        HStack(spacing: 24) {
            Button("Record", systemImage: "record.circle") {}
                .auditTarget("record")
            Button("Markers", systemImage: "flag") {}
                .auditTarget("markers")
        }
        .labelStyle(.iconOnly)
        .font(.title)
    }
}
```

Keep `nonisolated` on `TargetReport`. In a new Xcode 27.1 app, `SWIFT_DEFAULT_ACTOR_ISOLATION` is `MainActor`, which makes the struct's `Equatable` conformance main-actor isolated, and `onGeometryChange` then rejects it (the same fix as `FoldGeometry` in `duo-patterns`).

### What it printed

*Measured* on the closed simulator (iOS 27.1, portrait, 18 Oct 2026):

```text
TARGET tiny: 22 x 13 pt, under 44 pt
TARGET centre: 103 x 34 pt, under 44 pt
```

`tiny` was a plain text button in `.caption2`. `centre` was a `.borderedProminent` button at the default `.regular` control size. Both are smaller than 44 pt in layout. Apple doesn't document whether system buttons accept taps outside their frame, so read a system button's line as "check it", and a custom control's line as "fix it".

### Limits

- The fold line is *unverified*. We could not change poses in this run, so we never saw a control on an active fold. The closed phone has no fold.
- On the closed phone, the region query on a 382 × 562 pt view also returned the two camera and status bar regions in the bar strip, outside the view's frame. Apple's doc says the query returns regions that intersect the view. That is why the code tests `intersects(bounds)` itself instead of trusting a non-empty result.
- The audit measures the view it is attached to. Attach it to the button, not to a stack around several buttons.
- Remove the calls, or keep them inside `#if DEBUG`, before you ship. The geometry callback still runs in release builds.

## Review screenshots

Take screenshots with `xcrun simctl io <UDID> screenshot --display=primary outer.png` (closed) and `--display=primary-1 inner.png` (open). They come out at 3x, so multiply points by 3.

| What to check | Where, in pixels | Source |
|---|---|---|
| Hit regions | 44 pt is 132 px on each side | [HIG, Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons#Best-practices) |
| Space between bezeled targets | about 12 pt, 36 px | [HIG, Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility#Mobility) |
| Fold band, held wide (book) | x 1365–1485 px, full height | *measured* in `duo-patterns` (x 455–495 pt) |
| Fold band, held tall (tabletop) | y 1365–1485 px, full width | *measured* in `duo-patterns` (y 455–495 pt) |
| Top centre, held wide | x 951–1902 px, y 0–1005 px | *judgement*: the middle third of 951 pt, the top half of 669 pt |
| Bar strip, closed portrait, left to right | x 1146–1398 px | *measured*: 84 pt trailing inset in a 466 pt window |

Flag, most serious first:

1. Anything interactive in a fold band when the phone is partly folded.
2. A frequent action in the top centre of the open display.
3. A frequent control under 132 × 132 px.
4. A floating button far from the bar's side, or touching the bar's items.
5. A tabletop layout with controls in the top half.

`duo-design-review` turns these into findings: R4 (nothing interactive in the fold), R7 (tabletop and book layouts) and R13 (touch targets of 44 pt).
