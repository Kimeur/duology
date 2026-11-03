import Foundation
import Observation

/// The studio: the camera (real, or the stand-in when there is none), the mode, the self-timer,
/// recording, the gallery and the subject view's switch. `RootView` owns the one store, above
/// every layout decision, so opening, closing and folding the phone never stop a countdown or
/// a recording, and the outer display's subject view reads the same state as the photographer.
@Observable
final class StudioStore {
    /// The real camera, or the stand-in when this device has none (the simulator).
    let capture: CaptureService?
    var usesStandIn: Bool { capture == nil }

    private(set) var access: CameraAccess
    private(set) var mode: CaptureMode = .photo
    private(set) var side: CameraSide = .back
    var timer: TimerSetting = .off
    private(set) var countdown: Countdown?
    /// When the recording started; nil when not recording.
    private(set) var recordingStarted: Date?
    var isRecording: Bool { recordingStarted != nil }
    /// A photo or a movie is being saved.
    private(set) var isSaving = false
    private(set) var library: CaptureLibrary
    private(set) var lastError: String?

    var showsGallery = false
    /// The photographer's switch for the subject view. On by default.
    var showsSubjectView = true
    /// Whether the system can show the subject view now. Only the system sets it.
    var subjectViewAvailable = false

    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private let standIn = StandInRecorder()
    @ObservationIgnored private var recordingID: String?
    @ObservationIgnored private let folder: URL

    init(capture: CaptureService?, folder: URL) {
        self.capture = capture
        self.folder = folder
        access = capture == nil ? .noCamera : CaptureService.access()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let index = folder.appendingPathComponent(AppFacts.indexFile)
        var library = (try? Data(contentsOf: index)).flatMap { try? CaptureLibrary.decode($0) } ?? CaptureLibrary()
        let files = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
        library.keepOnly(existing: files)
        self.library = library
    }

    /// The store the app starts with: the real camera if there is one, then the launch switches.
    static func launch() -> StudioStore {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = documents.appendingPathComponent(AppFacts.capturesFolder)
        if LaunchOptions.resetsState { try? FileManager.default.removeItem(at: folder) }
        let useReal = CaptureService.hasCamera && !LaunchOptions.forcesStandIn
        let store = StudioStore(capture: useReal ? CaptureService() : nil, folder: folder)
        LaunchOptions.apply(to: store)
        return store
    }

    func url(for capture: Capture) -> URL { folder.appendingPathComponent(capture.fileName) }
    func posterURL(for capture: Capture) -> URL { folder.appendingPathComponent(capture.posterName) }

    // MARK: The camera

    /// Asks for the camera (and the microphone in video mode), then starts it. Safe to call again.
    func prepare() async {
        guard let capture else { return }
        guard await CaptureService.requestAccess(for: .video) else {
            access = CaptureService.access()
            return
        }
        access = .authorized
        let audio = mode == .video ? await CaptureService.requestAccess(for: .audio) : false
        await capture.configure(side: side, mode: mode, withAudio: audio)
        await capture.start()
    }

    func setMode(_ newMode: CaptureMode) {
        guard newMode != mode, !isRecording else { return }
        cancelTimer()
        mode = newMode
        Task { await prepare() }
    }

    func switchCamera() {
        guard !isRecording else { return }
        side = side == .back ? .front : .back
        Task { await prepare() }
    }

    // MARK: The shutter

    /// Photo: takes one, after the timer if set. Video: starts recording (after the timer) or stops.
    /// A tap during a countdown cancels it.
    func shutter() {
        if countdown != nil {
            cancelTimer()
            return
        }
        if isRecording {
            Task { await stopRecording() }
            return
        }
        guard !isSaving else { return }
        if timer == .off {
            fire()
        } else {
            startCountdown(seconds: timer.rawValue)
        }
    }

    func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
        countdown = nil
    }

    private func startCountdown(seconds: Int) {
        countdown = Countdown(seconds: seconds)
        timerTask = Task { [weak self] in
            while let self, var countdown = self.countdown {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                let done = countdown.tick()
                self.countdown = done ? nil : countdown
                if done {
                    self.timerTask = nil
                    self.fire()
                    return
                }
            }
        }
    }

    private func fire() {
        switch mode {
        case .photo: Task { await takePhoto() }
        case .video: Task { await startRecording() }
        }
    }

    // MARK: Saving

    private func takePhoto() async {
        isSaving = true
        defer { isSaving = false }
        let item = Capture(kind: .photo, isStandIn: usesStandIn)
        do {
            let data: Data
            if let capture {
                data = try await capture.capturePhoto()
            } else {
                let time = Date().timeIntervalSinceReferenceDate
                guard let image = StandInFrame.render(size: AppFacts.standInSize, time: time),
                      let jpeg = StandInFrame.jpeg(image) else { throw CaptureError.noPhotoData }
                data = jpeg
            }
            try data.write(to: url(for: item), options: .atomic)
            add(item)
        } catch {
            lastError = "The photo couldn't be saved."
        }
    }

    private func startRecording() async {
        // Busy while starting, so a second tap can't start a second recording.
        isSaving = true
        defer { isSaving = false }
        let item = Capture(kind: .video, isStandIn: usesStandIn)
        do {
            if let capture {
                try await capture.startRecording(to: url(for: item))
            } else {
                try await standIn.start(to: url(for: item))
            }
            recordingID = item.id
            recordingStarted = Date()
        } catch {
            lastError = "Recording couldn't start."
        }
    }

    private func stopRecording() async {
        guard let id = recordingID, let started = recordingStarted else { return }
        recordingID = nil
        recordingStarted = nil
        isSaving = true
        defer { isSaving = false }
        var item = Capture(id: id, kind: .video, created: started, isStandIn: usesStandIn)
        do {
            if let capture {
                _ = try await capture.stopRecording()
                item.duration = Date().timeIntervalSince(started)
            } else {
                item.duration = try await standIn.stop()
            }
            let poster = await Poster.jpeg(fromMovieAt: url(for: item))
            try poster?.write(to: posterURL(for: item), options: .atomic)
            add(item)
        } catch {
            try? FileManager.default.removeItem(at: url(for: item))
            lastError = "The video couldn't be saved."
        }
    }

    private func add(_ item: Capture) {
        library.add(item)
        lastError = nil
        saveIndex()
    }

    func delete(_ id: Capture.ID) {
        for name in library.remove(id) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
        saveIndex()
    }

    private func saveIndex() {
        guard let data = try? library.encoded() else { return }
        try? data.write(to: folder.appendingPathComponent(AppFacts.indexFile), options: .atomic)
    }
}
