import AVFoundation
import SwiftUI
import UIKit

/// A view whose layer is the camera preview.
final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

/// The live camera preview in SwiftUI. `onCreate` receives the view once, so the caller can
/// set up what depends on its layer (rotation, mirroring). The view keeps its identity through
/// every fold, so the layer and its coordinators keep working.
struct CameraPreview: UIViewRepresentable {
    let source: PreviewSource
    var gravity: AVLayerVideoGravity = .resizeAspect
    var onCreate: (PreviewView) -> Void = { _ in }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.videoGravity = gravity
        source.connect(view.previewLayer)
        onCreate(view)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.previewLayer.videoGravity = gravity
    }
}

/// The stand-in camera's live picture: `StandInFrame`'s bars and moving dot, drawn 30 times a
/// second, letterboxed to 4:3 like the real preview. Mirrored on the outer display, like the
/// real subject preview.
struct StandInPreview: View {
    var mirrored = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            Canvas { canvas, size in
                // Letterboxed to 4:3 inside whatever space the preview gets, like the real
                // preview's .resizeAspect gravity.
                let frame = StandInFrame.fitted(AppFacts.standInSize, in: size)
                canvas.translateBy(x: frame.minX, y: frame.minY)
                if mirrored {
                    canvas.translateBy(x: frame.width, y: 0)
                    canvas.scaleBy(x: -1, y: 1)
                }
                let time = context.date.timeIntervalSinceReferenceDate
                for swatch in StandInFrame.swatches(in: frame.size, time: time) {
                    canvas.fill(Path(swatch.rect), with: .color(Color(red: swatch.red, green: swatch.green, blue: swatch.blue)))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .accessibilityElement()
        .accessibilityLabel(mirrored ? "Stand-in camera picture, mirrored" : "Stand-in camera picture")
    }
}
