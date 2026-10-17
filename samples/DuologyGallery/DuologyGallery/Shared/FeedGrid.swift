import SwiftUI

/// What a grid needs to know, in the grid's own coordinate space.
/// Only x values are kept, so scrolling does not trigger a new layout.
///
/// Same type as the `duo-patterns` skill's feed reflow recipe.
nonisolated struct FeedGridInput: Equatable, Sendable {
    var width: CGFloat = 0
    /// Left and right edges of a top-to-bottom fold that crosses the grid, margins included.
    var foldMinX: CGFloat?
    var foldMaxX: CGFloat?
    var foldIsActive = false

    init(width: CGFloat = 0, foldMinX: CGFloat? = nil, foldMaxX: CGFloat? = nil, foldIsActive: Bool = false) {
        self.width = width
        self.foldMinX = foldMinX
        self.foldMaxX = foldMaxX
        self.foldIsActive = foldIsActive
    }

    @available(iOS 27.1, *)
    init(_ proxy: GeometryProxy) {
        width = proxy.size.width
        let folds = proxy.reservedRegions(kind: .division, options: .includeInactive)
        guard let fold = folds.first(where: \.isActive) ?? folds.first else { return }
        let frame = fold.frame
        // Ignore a fold that runs side to side or misses the grid.
        guard frame.height > frame.width, frame.minX > 0, frame.maxX < width else { return }
        foldMinX = frame.minX
        foldMaxX = frame.maxX
        foldIsActive = fold.isActive
    }
}

/// Columns for a feed. A pure function, so it can be tested on the Mac.
///
/// - Picks the count from the grid's width and a minimum tile width.
/// - Rounds down to an even count when a fold crosses the grid, active or not,
///   so the grid doesn't jump from 5 to 4 columns the moment the phone folds.
/// - While the fold is active, puts half the columns on each side and makes
///   the fold's frame the middle gap.
nonisolated func feedColumns(for input: FeedGridInput, minTileWidth: CGFloat, spacing: CGFloat) -> [GridItem] {
    guard input.width > 0 else { return [GridItem(.flexible(), spacing: spacing)] }
    var count = max(1, Int((input.width + spacing) / (minTileWidth + spacing)))
    if input.foldMinX != nil { count = max(2, count - count % 2) }

    guard input.foldIsActive, let minX = input.foldMinX, let maxX = input.foldMaxX else {
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
    }
    let half = count / 2
    let gaps = CGFloat(half - 1) * spacing
    let leftTile = (minX - gaps) / CGFloat(half)
    let rightTile = (input.width - maxX - gaps) / CGFloat(half)
    return (0..<count).map { index in
        let tile = index < half ? leftTile : rightTile
        let gapAfter = index == half - 1 ? maxX - minX : spacing
        return GridItem(.fixed(max(1, tile)), spacing: gapAfter)
    }
}

extension View {
    /// Reads the grid input from this view's geometry. Attach it to the grid
    /// itself, inside the scroll view, before any margins.
    func onFeedGridChange(_ action: @escaping (FeedGridInput) -> Void) -> some View {
        modifier(FeedGridReader(action: action))
    }

    /// The system's container margins, which can differ on each side next to a
    /// vertical bar on iPhone Duo (iOS 27.1). Earlier systems get standard padding.
    func containerMargins(_ edges: Edge.Set = .horizontal) -> some View {
        modifier(ContainerMargins(edges: edges))
    }
}

private struct FeedGridReader: ViewModifier {
    let action: (FeedGridInput) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onGeometryChange(for: FeedGridInput.self) { proxy in
                FeedGridInput(proxy)
            } action: { input in
                action(input)
            }
        } else {
            content.onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                action(FeedGridInput(width: width))
            }
        }
    }
}

private struct ContainerMargins: ViewModifier {
    let edges: Edge.Set

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.contentMargins(for: .container, edges: edges)
        } else {
            content.padding(edges)
        }
    }
}
