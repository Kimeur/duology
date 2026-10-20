import AVKit
import SwiftUI
import UIKit

/// Shows the model's video layer, with no system controls, so the same custom
/// controls show in every pose. It never makes its own layer: the layer, the
/// player and Picture in Picture live in `PlayerModel`.
struct VideoSurface: UIViewRepresentable {
    let model: PlayerModel

    func makeUIView(context: Context) -> VideoHostView {
        model.surfaceMade()
        let view = VideoHostView()
        view.backgroundColor = .black
        view.host(model.playerLayer)
        view.onWindow = { [weak model] in model?.surfaceIsOnScreen() }
        return view
    }

    func updateUIView(_ view: VideoHostView, context: Context) {
        // A new presentation of the player takes the layer back from an old view.
        view.host(model.playerLayer)
    }
}

/// A plain view that holds the model's `AVPlayerLayer` and keeps it the size of the view.
final class VideoHostView: UIView {
    private weak var hosted: CALayer?
    var onWindow: (() -> Void)?

    func host(_ videoLayer: CALayer) {
        guard videoLayer.superlayer !== layer else { return }
        videoLayer.removeFromSuperlayer()
        layer.addSublayer(videoLayer)
        hosted = videoLayer
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // No implicit animation: the layer follows the view's frame exactly when the phone folds.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hosted?.frame = bounds
        CATransaction.commit()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { onWindow?() }
    }
}

/// The system AirPlay button.
struct RoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = true
        picker.tintColor = .white
        picker.activeTintColor = .systemBlue
        return picker
    }

    func updateUIView(_ picker: AVRoutePickerView, context: Context) {}
}
