import AVFoundation
import Combine
import Foundation

/// Runs the rear camera and the record countdown.
final class CameraModel: ObservableObject {
    let session = AVCaptureSession()
    @Published private(set) var isCameraAvailable = false
    @Published private(set) var secondsToStart: Int?
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed = 0
    private var ticker: AnyCancellable?
    private let sessionQueue = DispatchQueue(label: "camera.session")

    func start() {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            isCameraAvailable = false
            return
        }
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        session.commitConfiguration()
        isCameraAvailable = true
        sessionQueue.async { [session] in session.startRunning() }
    }

    func stop() {
        sessionQueue.async { [session] in session.stopRunning() }
    }

    /// Counts down from 3, then records until tapped again.
    func toggleRecording() {
        if isRecording || secondsToStart != nil {
            ticker = nil
            secondsToStart = nil
            isRecording = false
            return
        }
        secondsToStart = 3
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        if let seconds = secondsToStart {
            if seconds > 1 {
                secondsToStart = seconds - 1
            } else {
                secondsToStart = nil
                isRecording = true
                elapsed = 0
            }
        } else if isRecording {
            elapsed += 1
        }
    }

    var elapsedText: String { String(format: "%02d:%02d", elapsed / 60, elapsed % 60) }
}
