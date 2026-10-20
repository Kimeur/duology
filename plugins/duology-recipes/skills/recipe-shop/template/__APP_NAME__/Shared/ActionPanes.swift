import SwiftUI

/// A screen with content and a purchase panel, such as the basket and the Plus screen.
///
/// Regular width (the open phone): two panes split on the fold, from `PaneFrames`. The
/// content scrolls on the leading side; the panel, its main button and the fine print on
/// the trailing side. Partly folded, the fold is the gap between them, so no button sits in it.
///
/// Compact width (the closed phone, a narrow Split View window): one column, and the main
/// button pinned to the bottom so it is always in reach.
struct ActionPanes<Content: View, Panel: View, Action: View, Footer: View>: View {
    let isTwoPane: Bool
    @ViewBuilder var content: Content
    @ViewBuilder var panel: Panel
    @ViewBuilder var action: Action
    @ViewBuilder var footer: Footer
    @DuoMetrics private var tokens
    @State private var geometry = PaneGeometry()

    var body: some View {
        Group {
            if isTwoPane {
                let frames = PaneFrames(width: geometry.width, count: tokens.columns,
                                        gutter: tokens.gutter, fold: geometry.fold)
                FoldPanes(frames: frames) {
                    ScrollView {
                        content.padding(.vertical, DuoSpace.x4)
                    }
                    .accessibilityIdentifier("pane.leading")
                } trailing: {
                    ScrollView {
                        VStack(alignment: .leading, spacing: tokens.sectionSpacing) {
                            panel
                            action
                            footer
                        }
                        .padding(.vertical, DuoSpace.x4)
                    }
                    .accessibilityIdentifier("pane.trailing")
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: tokens.sectionSpacing) {
                        content
                        panel
                        footer
                    }
                    .padding(.vertical, DuoSpace.x4)
                }
                .accessibilityIdentifier("pane.leading")
                .safeAreaInset(edge: .bottom) {
                    action
                        .padding(.vertical, DuoSpace.x3)
                        .background(DuoColor.groupedBackground)
                }
            }
        }
        // Measured inside the margins, so the fold comes back in the panes' coordinates.
        .onPaneGeometryChange { geometry = $0 }
        .duoContainerMargins()
        .background(DuoColor.groupedBackground)
    }
}
