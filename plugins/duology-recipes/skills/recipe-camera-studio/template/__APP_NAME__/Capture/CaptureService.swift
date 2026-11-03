import AVFoundation

/// Lets a preview layer on the main actor hold the session. `AVCaptureSession` isn't Sendable,
/// so this box is unchecked: only `connect(_:)` touches it, and all configuration stays on the
/// `CaptureService` actor.
nonisolated struct PreviewSource: @unchecked Sendable {
    fileprivate let session: AVCaptureSession

    @MainActor func connect(_ layer: AVCaptureVideoPreviewLayer) {
        layer.session = session
    }
}

/// Which camera: the rear camera films the subject; the front camera turns the studio around.
nonisolated enum CameraSide: String, Sendable {
    case back, front
}

nonisolated enum CaptureError: Error {
    case noCamera, notConfigured, noPhotoData, alreadyRecording, notRecording
    /// The movie didn't report back in time. It may still be being written.
    case timedOut
}

/// Owns the capture session. Every AVFoundation call that configures or runs capture happens
/// on this actor, never on the main actor (`startRunning()` blocks).
///
/// The simulator has no camera, so none of this runs there: the studio uses `StandInRecorder`
/// and `StandInFrame` instead. Typechecked against the iOS 27.1 SDK; not yet run on a device.
actor CaptureService {
    let session: AVCaptureSession
    nonisolated let previewSource: PreviewSource
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var rotations: [AVCaptureDevice.RotationCoordinator] = []
    private var rotationObservations: [NSKeyValueObservation] = []
    private var photoDelegates: [Int64: PhotoDelegate] = [:]
    private var movieDelegate: MovieDelegate?
    /// The preview layer on the outer display, and whether its picture is mirrored. Set again
    /// after every configuration: a new input makes a new preview connection, which starts with
    /// automatic mirroring (`duo-camera`).
    private var subjectLayerID: ObjectIdentifier?
    private var subjectMirrored = false

    init() {
        let session = AVCaptureSession()
        self.session = session
        previewSource = PreviewSource(session: session)
    }

    /// True when this device has any camera. The simulator has none (measured in `duo-camera`).
    nonisolated static var hasCamera: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    /// Asks once, then answers from the saved choice.
    nonisolated static func requestAccess(for media: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: media) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: media)
        default: return false
        }
    }

    nonisolated static func access() -> CameraAccess {
        guard hasCamera else { return .noCamera }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        default: return .notDetermined
        }
    }

    // MARK: Configuration

    /// Sets up the camera on `side` for `mode`. Video adds the movie output and, when allowed,
    /// the microphone. False when the camera is missing or doesn't fit; the old setup stays.
    @discardableResult
    func configure(side: CameraSide, mode: CaptureMode, withAudio: Bool) -> Bool {
        guard let camera = Self.camera(on: side), let input = try? AVCaptureDeviceInput(device: camera) else { return false }
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        let preset: AVCaptureSession.Preset = mode == .photo ? .photo : .high
        if session.canSetSessionPreset(preset) { session.sessionPreset = preset }

        if let videoInput { session.removeInput(videoInput) }
        guard session.canAddInput(input) else {
            // Put the old camera back, with its rotation and the subject's mirroring.
            if let videoInput {
                session.addInput(videoInput)
                trackRotation(of: videoInput.device)
                applySubjectMirroring()
            }
            return false
        }
        session.addInput(input)
        videoInput = input

        if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        if mode == .video {
            if !session.outputs.contains(movieOutput), session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
            }
            if withAudio, audioInput == nil, let mic = AVCaptureDevice.default(for: .audio),
               let micInput = try? AVCaptureDeviceInput(device: mic), session.canAddInput(micInput) {
                session.addInput(micInput)
                audioInput = micInput
            }
        } else {
            if session.outputs.contains(movieOutput) { session.removeOutput(movieOutput) }
            if let audioInput {
                session.removeInput(audioInput)
                self.audioInput = nil
            }
        }
        trackRotation(of: camera)
        applySubjectMirroring()
        return true
    }

    /// The rear wide camera, or the front camera every app asks for. On iPhone Duo the front
    /// one is the virtual front camera, which follows the app between the displays (`duo-camera`).
    private static func camera(on side: CameraSide) -> AVCaptureDevice? {
        switch side {
        case .back:
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        case .front:
            return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera],
                                                    mediaType: .video, position: .front).devices.first
        }
    }

    func start() {
        if !session.isRunning { session.startRunning() }
    }

    func stop() {
        if session.isRunning { session.stopRunning() }
    }

    // MARK: Photos

    /// Takes one photo and returns it as JPEG data.
    func capturePhoto() async throws -> Data {
        guard videoInput != nil else { throw CaptureError.notConfigured }
        let settings = photoOutput.availablePhotoCodecTypes.contains(.jpeg)
            ? AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            : AVCapturePhotoSettings()
        let id = settings.uniqueID
        defer { photoDelegates[id] = nil }
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PhotoDelegate(continuation: continuation)
            photoDelegates[id] = delegate          // the output holds its delegate weakly
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    // MARK: Video

    func startRecording(to url: URL) throws {
        guard session.outputs.contains(movieOutput) else { throw CaptureError.notConfigured }
        guard !movieOutput.isRecording else { throw CaptureError.alreadyRecording }
        let delegate = MovieDelegate()
        movieDelegate = delegate
        movieOutput.startRecording(to: url, recordingDelegate: delegate)
    }

    /// Stops recording and returns the finished movie's address once it is written. Always asks
    /// the output to stop: `isRecording` turns true only once samples are written, so a Stop right
    /// after Start would otherwise leave it running. Gives up after 10 seconds without an answer.
    func stopRecording() async throws -> URL {
        guard let delegate = movieDelegate else { throw CaptureError.notRecording }
        movieDelegate = nil
        movieOutput.stopRecording()
        return try await delegate.finished(timeout: .seconds(10))
    }

    // MARK: Rotation and the subject's preview

    /// Call after a preview layer connects: a rotation coordinator serves one camera and one layer.
    func refreshRotation() {
        if let camera = videoInput?.device { trackRotation(of: camera) }
    }

    /// Call after the outer display's preview layer connects. Its rear-camera picture is mirrored:
    /// from the outer display the rear camera faces the subject, like a mirror (Apple's direction
    /// guide; `duo-camera`). Derived; not checked on a device.
    func attachSubjectPreview(_ layerID: ObjectIdentifier, mirrored: Bool) {
        subjectLayerID = layerID
        subjectMirrored = mirrored
        if let camera = videoInput?.device { trackRotation(of: camera) }
        applySubjectMirroring()
    }

    private func applySubjectMirroring() {
        guard let subjectLayerID, let connection = connection(for: subjectLayerID),
              connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false   // first, or the next line throws
        connection.isVideoMirrored = subjectMirrored
    }

    /// Keeps every preview and the captured photos and videos upright. On iPhone Duo the angles
    /// also change when the app moves to the other display (Tech Talk 111465).
    private func trackRotation(of camera: AVCaptureDevice) {
        rotations = []
        rotationObservations = []
        for layer in session.connections.compactMap(\.videoPreviewLayer) {
            let coordinator = AVCaptureDevice.RotationCoordinator(device: camera, previewLayer: layer)
            let layerID = ObjectIdentifier(layer)
            rotations.append(coordinator)
            rotationObservations.append(coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] _, change in
                guard let angle = change.newValue else { return }
                Task { await self?.rotatePreview(layerID, to: angle) }
            })
        }
        if let first = rotations.first {
            rotationObservations.append(first.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { [weak self] _, change in
                guard let angle = change.newValue else { return }
                Task { await self?.rotateCapture(to: angle) }
            })
        }
        // The coordinator keeps photos upright, so the compensation for older sensor
        // orientations only costs time (Tech Talk 111465, at 8:37).
        if photoOutput.isCameraSensorOrientationCompensationSupported {
            photoOutput.isCameraSensorOrientationCompensationEnabled = false
        }
    }

    private func connection(for layerID: ObjectIdentifier) -> AVCaptureConnection? {
        session.connections.first { $0.videoPreviewLayer.map(ObjectIdentifier.init) == layerID }
    }

    private func rotatePreview(_ layerID: ObjectIdentifier, to angle: CGFloat) {
        guard let connection = connection(for: layerID), connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    private func rotateCapture(to angle: CGFloat) {
        for output in [photoOutput, movieOutput] as [AVCaptureOutput] {
            guard let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(angle) else { continue }
            connection.videoRotationAngle = angle
        }
    }
}

/// Hands one photo's data back to the waiting task. AVFoundation calls it on its own queue.
nonisolated private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<Data, any Error>?

    init(continuation: CheckedContinuation<Data, any Error>) {
        self.continuation = continuation
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        if let error {
            continuation?.resume(throwing: error)
        } else if let data = photo.fileDataRepresentation() {
            continuation?.resume(returning: data)
        } else {
            continuation?.resume(throwing: CaptureError.noPhotoData)
        }
        continuation = nil
    }

    /// Always the last call for a capture. If no photo came, the waiting task still gets an answer.
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: (any Error)?) {
        continuation?.resume(throwing: error ?? CaptureError.noPhotoData)
        continuation = nil
    }
}

/// Waits for a movie to finish writing. The recording can end before anyone waits (a full disk,
/// an interruption), so the result is kept until `finished()` asks for it.
nonisolated private final class MovieDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<URL, any Error>?
    private var waiting: CheckedContinuation<URL, any Error>?

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: (any Error)?) {
        // A movie that stopped for a reason such as a full disk can still be complete.
        let finished = (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool
        deliver(error == nil || finished == true ? .success(outputFileURL) : .failure(error!))
    }

    /// The first outcome wins; later ones (a late callback after a time-out) are dropped.
    private func deliver(_ outcome: Result<URL, any Error>) {
        lock.lock()
        guard result == nil else {
            lock.unlock()
            return
        }
        result = outcome
        let waiting = self.waiting
        self.waiting = nil
        lock.unlock()
        waiting?.resume(with: outcome)
    }

    func finished(timeout: Duration) async throws -> URL {
        let seconds = Double(timeout.components.seconds)
        DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { [self] in
            deliver(.failure(CaptureError.timedOut))
        }
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let result {
                lock.unlock()
                continuation.resume(with: result)
            } else {
                waiting = continuation
                lock.unlock()
            }
        }
    }
}
