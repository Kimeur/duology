# A fold readout, to tell open from book

From outside the app, open and book look the same: the inner display is active and held wide in both, and Device Hub doesn't report the pose. The app knows. Its fold is a `division` reserved region that is inactive when the phone is flat and active when it is partly folded ([API index: reserved regions](https://github.com/Kimeur/duology/blob/main/reference/api-index.md#reserved-regions-and-margins)). Closed, there is no division region at all (*measured* in the gallery's region overlay).

This page adds a debug-only readout that shows that state as one accessibility element, and explains how `--readout-id` reads it.

## The readout

It typechecks against the iOS 27.1 SDK with deployment targets 27.1 and 26.0. Copy it into the app target, and attach `.poseReadout()` once, to the root view.

```swift
import SwiftUI

/// Debug only. Shows the fold's state to UI scripting tools such as
/// `duo-pose-matrix --readout-id duo.pose`, through one accessibility element.
/// Its value is "fold=none" (closed), "fold=inactive" (open flat) or
/// "fold=active" (partly folded: book or tabletop).
/// Launch with `-duoPoseReadout YES` to turn it on.
struct PoseReadout: ViewModifier {
    @State private var fold = "none"
    private let isOn = UserDefaults.standard.bool(forKey: "duoPoseReadout")

    func body(content: Content) -> some View {
        #if DEBUG
        if #available(iOS 27.1, *), isOn {
            content
                .overlay {
                    Color.clear
                        .ignoresSafeArea()
                        .onGeometryChange(for: String.self) { proxy in
                            let folds = proxy.reservedRegions(kind: .division, options: .includeInactive)
                            guard let region = folds.first else { return "none" }
                            return region.isActive ? "active" : "inactive"
                        } action: { newValue in
                            fold = newValue
                        }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .overlay(alignment: .bottomLeading) {
                    Text("fold=\(fold)")
                        .font(.caption2.monospaced())
                        .padding(4)
                        .background(.background.opacity(0.8))
                        .accessibilityIdentifier("duo.pose")
                        .accessibilityValue("fold=\(fold)")
                        .allowsHitTesting(false)
                }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

extension View {
    /// Attach once, to the root view.
    func poseReadout() -> some View {
        modifier(PoseReadout())
    }
}
```

Why it is built this way:

- It reads the region in `onGeometryChange`, like the gallery's region overlay. That runs on the first layout and on every resize, so a fresh launch in book pose reports `active` at once. The gallery found that a first read in `onAppear` can come back empty.
- `includeInactive` returns the fold when the phone is flat, so open and closed differ (`inactive` versus `none`).
- The overlay that measures fills the screen, so the fold always lies inside the view that asks. Region frames come back in that view's own space. Duology hasn't tested what a small view in a corner gets back.
- The label is visible on purpose. It shows in every screenshot, so a person reading the PNG sees the fold state too. It is compiled only in debug builds and only shown with `-duoPoseReadout YES`, so release builds and normal runs never show it.
- The `-duoPoseReadout YES` launch argument works because launch arguments of the form `-key value` land in `UserDefaults`.

## Use it

```bash
duo-pose-matrix com.example.places --readout-id duo.pose -- -duoPoseReadout YES
duo-pose set book --readout-id duo.pose      # with the app already running with the readout on
```

The helper looks inside Device Hub's window for an element whose accessibility identifier is `duo.pose` and reads its value. Device Hub shows the running app's accessibility tree inside its window (*measured*: app elements such as a Home picker button appeared with their identifiers in a tree dump on 17 October). The tool then expects:

| Pose | Value |
|---|---|
| closed | `fold=none` |
| open | `fold=inactive` |
| book, tabletop | `fold=active` |

A value with a `DeviceHinge.Status` name (`closed`, `partiallyOpen`, `fullyOpen`) works too, if your app already exposes the hinge that way.

A mismatch fails the shot with "the app says the hinge is ..., expected ...". No element found leaves the fold "not checked".

## Not verified yet

- *Unverified:* reading this element through Device Hub end to end. Our live runs pressed the buttons in Device Hub's window, but the gallery app has no readout yet, so `--readout-id` is tested only against the fake simulator in `tests/`.
- *Unverified:* whether the region reports `none` at the very first layout of a launch made while the phone is closed, before the system settles the scene. The gallery's overlay showed no fold when closed.
- In Split View or a window that doesn't touch the fold, the region query can return nothing even when the phone is folded. The matrix captures full-screen apps only.
