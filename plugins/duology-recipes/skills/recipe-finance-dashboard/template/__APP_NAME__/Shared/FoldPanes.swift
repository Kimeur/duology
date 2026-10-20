import SwiftUI

extension DuoFold {
    /// The fold in `proxy`'s view, active or not. Nil on the outer display, when the fold
    /// runs side to side (the open phone held tall), or when it misses the view or only
    /// touches its edge (a Split View window that ends at the fold).
    @available(iOS 27.1, *)
    nonisolated init?(_ proxy: GeometryProxy) {
        // The default query returns active regions only, so a flat phone would report no
        // fold. Ask for inactive ones too: then the panes sit in the same place flat and folded.
        let folds = proxy.reservedRegions(kind: .division, options: .includeInactive)
        guard let fold = folds.first(where: \.isActive) ?? folds.first else { return nil }
        let frame = fold.frame
        guard frame.height > frame.width, frame.minX > 0, frame.maxX < proxy.size.width else { return nil }
        self.init(minX: frame.minX, maxX: frame.maxX, isActive: fold.isActive)
    }
}

/// What a two-pane screen needs to know about its own box. Equatable, so
/// `onGeometryChange` fires only when the width or the fold changes, never on scroll.
nonisolated struct PaneGeometry: Equatable, Sendable {
    var width: CGFloat = 0
    var fold: DuoFold?
}

extension View {
    /// Calls `action` with this view's width and fold now and whenever they change.
    /// Put it on a view that fills the offered width, inside the margins, so the
    /// fold comes back in the panes' own coordinates.
    func onPaneGeometryChange(_ action: @escaping (PaneGeometry) -> Void) -> some View {
        modifier(PaneGeometryReader(action: action))
    }
}

private struct PaneGeometryReader: ViewModifier {
    let action: (PaneGeometry) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onGeometryChange(for: PaneGeometry.self) { proxy in
                PaneGeometry(width: proxy.size.width, fold: DuoFold(proxy))
            } action: { geometry in
                action(geometry)
            }
        } else {
            // No fold to read before iOS 27.1: two equal panes.
            content.onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                action(PaneGeometry(width: width))
            }
        }
    }
}

/// One pane at full width, or two panes split on the fold.
///
/// The frames come from `PaneFrames` (Model/DuoColumns.swift): half of an even grid on each
/// side, with the fold as the middle gutter. Each pane gets compact width, so the tokens and
/// views inside it lay out for a half, not for the whole inner display.
struct FoldPanes<Leading: View, Trailing: View>: View {
    /// Nil shows the leading pane alone, at full width.
    var frames: PaneFrames?
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    @Environment(\.horizontalSizeClass) private var widthClass

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            leading
                .frame(width: frames?.leading.width)
                .frame(maxWidth: frames == nil ? .infinity : nil, maxHeight: .infinity, alignment: .top)
            if let frames {
                trailing
                    .frame(width: frames.trailing.width)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.leading, frames.gap)
            }
        }
        // A custom split keeps the window's regular width class in each half (measured in
        // duo-layout). Each pane is a half, so give it compact width.
        .environment(\.horizontalSizeClass, frames == nil ? widthClass : .compact)
        .padding(.leading, frames?.leading.x ?? 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
