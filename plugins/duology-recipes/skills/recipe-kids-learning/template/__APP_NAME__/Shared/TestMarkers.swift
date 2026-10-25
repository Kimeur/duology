import SwiftUI

extension View {
    /// A machine-readable state for UI tests, such as "activity=counting|question=0|stars=1|".
    /// Only with -uiTesting in a debug build: VoiceOver never meets the extra element.
    @ViewBuilder
    func testMarker(_ id: String, value: @autoclosure () -> String) -> some View {
        if LaunchOptions.isUITesting {
            overlay {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier(id)
                    .accessibilityValue(value())
                    .allowsHitTesting(false)
            }
        } else {
            self
        }
    }

    /// An element exactly the size of this view, so a UI test can read a pane's frame: a
    /// container's own frame in a UI test is the union of its children, not the pane.
    /// UI tests only.
    @ViewBuilder
    func frameMarker(_ id: String) -> some View {
        if LaunchOptions.isUITesting {
            background {
                Color.clear
                    .accessibilityElement()
                    .accessibilityLabel("Pane outline for tests")
                    .accessibilityIdentifier(id)
                    .allowsHitTesting(false)
            }
        } else {
            self
        }
    }

    /// An element exactly where the fold is, so a UI test can compare it with the buttons'
    /// frames in its own coordinates. Put it on the view the fold was read on. UI tests only.
    @ViewBuilder
    func foldMarker(_ fold: FoldGeometry) -> some View {
        if LaunchOptions.isUITesting, let frame = fold.frame {
            overlay(alignment: .topLeading) {
                Color.clear
                    .frame(width: frame.width, height: frame.height)
                    .accessibilityElement()
                    .accessibilityIdentifier("fold")
                    .accessibilityValue(fold.isActive ? "folded" : "flat")
                    .allowsHitTesting(false)
                    .offset(x: frame.minX, y: frame.minY)
            }
        } else {
            self
        }
    }
}

extension FoldGeometry {
    /// "455,0,40,669" in the view's space, or "" with no fold. For test markers.
    var markerText: String {
        guard let frame else { return "" }
        return [frame.minX, frame.minY, frame.width, frame.height]
            .map { String(format: "%g", ($0 * 2).rounded() / 2) }
            .joined(separator: ",")
    }
}
