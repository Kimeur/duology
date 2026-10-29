import SwiftUI

extension FoldGeometry {
    /// Reads the fold from a view's reserved regions. The default query returns
    /// active regions only, so ask for inactive ones too: a flat inner display
    /// then still says where its fold is. `nonisolated`, because
    /// `onGeometryChange` runs its transform off the main actor.
    @available(iOS 27.1, *)
    nonisolated init(_ proxy: GeometryProxy) {
        let regions = proxy.reservedRegions(kind: .division, options: .includeInactive)
        self.init(candidates: regions.map { (frame: $0.frame, isActive: $0.isActive) }, in: proxy.size)
    }
}

extension View {
    /// Calls `action` with the fold now and every time it changes. Reads regions
    /// in `onGeometryChange`, not `onAppear`: the first layout pass has none.
    /// Before iOS 27.1 it never calls `action`; there is no fold to read.
    func onFoldChange(_ action: @escaping (FoldGeometry) -> Void) -> some View {
        modifier(FoldChangeReader(action: action))
    }
}

private struct FoldChangeReader: ViewModifier {
    let action: (FoldGeometry) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onGeometryChange(for: FoldGeometry.self) { proxy in
                FoldGeometry(proxy)
            } action: { fold in
                action(fold)
            }
        } else {
            content
        }
    }
}
