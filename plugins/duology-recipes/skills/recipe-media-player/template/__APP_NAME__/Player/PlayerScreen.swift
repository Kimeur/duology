import SwiftUI

/// The full-screen player. One layout in every pose (`FoldRegionsLayout`), so the
/// video and its controls keep their identity and playback never stops on a fold:
///
/// - Closed, and open flat: the controls float at the bottom. Closed and upright,
///   the picture moves up into the space above them.
/// - Folded like a book: the video in the leading region, the controls trailing.
/// - Folded across and propped on a table (tabletop): the video above the fold,
///   the same controls below it.
///
/// The controls are the same view in every pose, up next card included.
struct PlayerScreen: View {
    @Bindable var model: PlayerModel
    @State private var fold = FoldGeometry()
    @State private var size = CGSize.zero
    @State private var controlsHeight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The regions the layout uses now, or nil when the controls float over the video.
    private var regions: (video: CGRect, controls: CGRect)? {
        FoldRegions.split(CGRect(origin: .zero, size: size), fold: fold)
    }

    var body: some View {
        FoldRegionsLayout(fold: fold) {
            // First: what people watch.
            VideoFrame(model: model, covered: regions == nil ? controlsHeight : 0)
            // Second: what people touch. The same view in every pose.
            PlayerControls(model: model)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { controlsHeight = $0 }
        }
        // Read the fold on the layout itself, so its frame is in the layout's space.
        .onFoldChange { fold = $0 }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        // A short slide when the phone folds. With Reduce Motion the controls move at once.
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: fold)
        .background { Color.black.ignoresSafeArea() }
        .environment(\.colorScheme, .dark)
        .persistentSystemOverlays(.hidden)
        .testMarker("player.state", value: model.testSummary)
        .testMarker("player.layout", value: layoutSummary)
    }

    private var layoutSummary: String {
        guard let regions else { return "layout=overlay" }
        return regions.video.maxX <= regions.controls.minX ? "layout=side-by-side" : "layout=stacked"
    }
}

/// The video, kept at its own aspect ratio. While the controls float over it, it
/// sits in the space above them when it fits there whole.
private struct VideoFrame: View {
    let model: PlayerModel
    /// How much of this view's bottom edge the floating controls cover.
    let covered: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let picture = FoldRegions.picture(aspect: model.videoAspect, in: proxy.size, covered: covered)
            VideoSurface(model: model)
                .frame(width: picture.width, height: picture.height)
                .position(x: picture.midX, y: picture.midY)
                .accessibilityElement()
                .accessibilityLabel(model.current.map { "Video: \($0.title)" } ?? "Video")
                .accessibilityAddTraits(.startsMediaSession)
                .accessibilityIdentifier("player.video")
        }
    }
}

extension PlayerModel {
    /// The state UI tests read from the `player.state` marker. Every field ends with
    /// "|", so a test can look for "time=1|" without matching "time=12|".
    var testSummary: String {
        let card: String
        switch upNext {
        case .hidden: card = "hidden"
        case .counting: card = "counting"
        case .waiting: card = "waiting"
        }
        return [
            "item=\(current?.id ?? "none")",
            "playing=\(isPlaying ? 1 : 0)",
            "time=\(Int(position))",
            "upNext=\(card)",
            "pip=\(isPictureInPictureActive ? 1 : 0)",
            "surfaces=\(surfacesMade)",
            "presented=\(isPlayerPresented ? 1 : 0)"
        ].map { $0 + "|" }.joined()
    }
}
