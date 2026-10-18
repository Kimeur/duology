import SwiftUI

/// Two equal halves that always show. Side by side when the view is wider
/// than tall, stacked otherwise. AnyLayout keeps each half's state when the
/// axis flips.
///
/// Why not `ArrangementView`: a split arrangement may show only its primary
/// view when space is tight. In an earlier Duology test on the iOS 27.1
/// simulator, the closed phone held sideways (compact width, compact height)
/// showed only the first half. That is right for a list and its detail, and
/// wrong when both halves must stay on screen in every pose: two players, a
/// before and after, two halves of one diagram. Use `EvenSplit` for those,
/// and `ArrangementView` when hiding the secondary view is acceptable.
///
/// Why it is built this way:
/// - The axis follows the view's own shape, not the size class or the device,
///   so it is right on both displays, in Split View and in any window.
/// - `AnyLayout` instead of `if wide { HStack } else { VStack }`: an `if`
///   gives both halves a new identity when the axis flips, which resets
///   scroll positions, text fields and game state.
/// - Each half gets exactly half the space, so wide content can't push the seam.
///
/// The seam sits in the middle of this view, not on the fold. When the seam
/// must land on an active fold, split at the `.division` reserved region instead
/// (see `TwoPageView` and the `duo-layout` skill).
///
/// Same type as the `duo-layout` skill's `references/custom-split.md`.
struct EvenSplit<Primary: View, Secondary: View>: View {
    var spacing: CGFloat = 0
    @ViewBuilder var primary: () -> Primary
    @ViewBuilder var secondary: () -> Secondary

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= proxy.size.height
            let half = wide
                ? CGSize(width: max(0, (proxy.size.width - spacing) / 2), height: proxy.size.height)
                : CGSize(width: proxy.size.width, height: max(0, (proxy.size.height - spacing) / 2))
            let layout = wide
                ? AnyLayout(HStackLayout(spacing: spacing))
                : AnyLayout(VStackLayout(spacing: spacing))
            layout {
                primary().frame(width: half.width, height: half.height)
                secondary().frame(width: half.width, height: half.height)
            }
        }
    }
}
