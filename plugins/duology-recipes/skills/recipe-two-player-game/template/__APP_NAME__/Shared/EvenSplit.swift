import SwiftUI

/// Two equal halves that always show. Side by side when the view is wider
/// than tall, stacked otherwise. AnyLayout keeps each half's state when the
/// axis flips.
///
/// Same type as the Duology gallery's Shared/EvenSplit.swift. Why it is built this
/// way: duo-layout, references/custom-split.md.
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
