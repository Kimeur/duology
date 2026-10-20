import AVFoundation
import AVKit
import Observation
import UIKit

/// Playback for the whole app: one `AVPlayer`, one `AVPlayerLayer` and one Picture in
/// Picture controller. RootView creates it once, above every layout decision, so
/// folding, unfolding, rotating, closing the player screen and Picture in Picture
/// all keep the same player and the same layer. Nothing restarts.
@Observable
final class PlayerModel: NSObject {
    let catalog: Catalog

    @ObservationIgnored let player = AVPlayer()
    /// The video layer. `VideoSurface` shows it and never makes its own, so a new
    /// view (after a fold, or when the player opens again) shows the same picture.
    @ObservationIgnored let playerLayer = AVPlayerLayer()
    @ObservationIgnored private var pictureInPicture: AVPictureInPictureController?
    @ObservationIgnored private var possibleObservation: NSKeyValueObservation?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: (any NSObjectProtocol)?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isScrubbing = false
    /// How many video views were made. A test marker: it stays at 1 while the
    /// player screen is up, however often the phone folds.
    @ObservationIgnored private(set) var surfacesMade = 0

    private(set) var queue = PlaybackQueue()
    private(set) var position: Double = 0
    private(set) var duration: Double = 0
    private(set) var isPlaying = false
    private(set) var rate: Float = 1
    private(set) var videoAspect: CGFloat = 16 / 9
    private(set) var resume: ResumePositions
    private(set) var upNextDismissed = false
    private(set) var isPictureInPictureActive = false
    /// True once the Picture in Picture controller exists. Observed, so the button
    /// appears as soon as the video is on screen.
    private(set) var canPictureInPicture = false
    /// False while the system can't start Picture in Picture now, for example during
    /// a FaceTime call. The button is disabled then.
    private(set) var isPictureInPicturePossible = false
    var isPlayerPresented = false
    var upNextPolicy = UpNextPolicy()
    /// Debug switch -loop: replay the episode at its end instead of moving on.
    var loops = false

    init(catalog: Catalog, defaults: UserDefaults = .standard) {
        self.catalog = catalog
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.resumeKey),
           let saved = try? JSONDecoder().decode(ResumePositions.self, from: data) {
            resume = saved
        } else {
            resume = ResumePositions()
        }
        super.init()
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        observePlayback()
    }

    /// The model the app starts with: the bundled catalogue, then the launch switches.
    static func launch() -> PlayerModel {
        let model = PlayerModel(catalog: .bundled)
        LaunchOptions.apply(to: model)
        return model
    }

    var current: Episode? { queue.current.flatMap(catalog.episode) }
    var next: Episode? { queue.next.flatMap(catalog.episode) }
    var currentShow: Show? { queue.current.flatMap(catalog.show(of:)) }

    var upNext: UpNextState {
        upNextPolicy.card(position: position, duration: duration, hasNext: next != nil, dismissed: upNextDismissed)
    }

    // MARK: Playing

    /// Starts a new queue: this episode, then the rest of its show.
    func play(_ episode: Episode, from start: Double? = nil, startPaused: Bool = false) {
        recordPosition()
        queue.start(episode.id, then: catalog.following(episode.id).map(\.id))
        load(episode, from: start ?? resume.resume(episode.id), autoplay: !startPaused)
    }

    func togglePlayback() {
        if isPlaying {
            player.pause()
            isPlaying = false
            recordPosition()
            save()
        } else {
            if duration > 0, position >= duration - 0.25 { seek(to: 0) }
            activateAudioSession()
            player.playImmediately(atRate: rate)
            isPlaying = true
        }
    }

    func skip(by seconds: Double) {
        seek(to: position + seconds)
    }

    func seek(to seconds: Double) {
        let target = min(max(0, seconds), max(0, duration))
        position = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// The scrubber calls this while a finger is on it, so ticks don't fight the drag.
    func setScrubbing(_ scrubbing: Bool) {
        isScrubbing = scrubbing
        if !scrubbing { recordPosition() }
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        player.defaultRate = newRate
        if isPlaying { player.rate = newRate }
    }

    /// Plays the next episode in the queue now.
    func playNext() {
        recordPosition()
        guard let id = queue.advance(), let episode = catalog.episode(id) else { return }
        load(episode, from: resume.resume(id), autoplay: true)
        save()
    }

    /// Closes the up next card. This episode then stops at its end.
    func dismissUpNext() {
        upNextDismissed = true
    }

    // MARK: Picture in Picture

    /// Called by `VideoSurface` once its view is in a window. The controller needs
    /// the layer on screen to set up; after that it belongs to the model.
    func surfaceIsOnScreen() {
        guard pictureInPicture == nil, AVPictureInPictureController.isPictureInPictureSupported(),
              let controller = AVPictureInPictureController(playerLayer: playerLayer) else { return }
        controller.delegate = self
        // Going home while playing floats the video instead of stopping it.
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        pictureInPicture = controller
        canPictureInPicture = true
        // Key-value observing may report on any thread, so hop to the main actor.
        possibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) {
            @Sendable [weak self] controller, _ in
            let possible = controller.isPictureInPicturePossible
            Task { @MainActor in self?.isPictureInPicturePossible = possible }
        }
    }

    func surfaceMade() {
        surfacesMade += 1
    }

    func togglePictureInPicture() {
        guard let controller = pictureInPicture else { return }
        if controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
        } else {
            controller.startPictureInPicture()
        }
    }

    // MARK: Background

    /// The window went to the background (true) or came back (false).
    ///
    /// iOS pauses a video whose layer is on screen when the app leaves it. Taking the
    /// player off its layer lets the sound go on, the way a podcast should. Picture
    /// in Picture shows the picture, so it keeps the layer.
    func sceneMovedToBackground(_ background: Bool) {
        if background {
            saveProgress()
            if !isPictureInPictureActive { playerLayer.player = nil }
        } else {
            playerLayer.player = player
        }
    }

    // MARK: Saving

    func saveProgress() {
        recordPosition()
        save()
    }

    private func recordPosition() {
        guard let id = queue.current, duration > 0 else { return }
        resume.record(id, at: position, duration: duration)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(resume) {
            defaults.set(data, forKey: Self.resumeKey)
        }
    }

    private static let resumeKey = "resumePositions"

    // MARK: Player plumbing

    private func load(_ episode: Episode, from start: Double, autoplay: Bool) {
        guard let url = Self.url(for: episode) else { return }
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        duration = episode.duration
        position = 0
        upNextDismissed = false
        if start > 0 { seek(to: start) }
        if autoplay {
            activateAudioSession()
            player.playImmediately(atRate: rate)
        } else {
            player.pause()
        }
        isPlaying = autoplay
    }

    /// The app sets the playback category at launch; Apple suggests activating the
    /// session only when playback starts, so other apps' audio isn't cut off early.
    private func activateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private static func url(for episode: Episode) -> URL? {
        if let remote = episode.remoteURL { return remote }
        guard let file = episode.bundledFile else { return nil }
        return Bundle.main.url(forResource: file.name, withExtension: file.ext)
    }

    private func observePlayback() {
        // Four times a second while playing, and whenever playback starts or stops.
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 4), queue: .main) {
            [weak self] time in
            MainActor.assumeIsolated { self?.tick(time) }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let item = notification.object as? AVPlayerItem
            MainActor.assumeIsolated {
                guard let self, item === self.player.currentItem else { return }
                self.itemDidEnd()
            }
        }
    }

    private func tick(_ time: CMTime) {
        guard let item = player.currentItem else { return }
        if !isScrubbing, time.seconds.isFinite { position = time.seconds }
        let length = item.duration.seconds
        if length.isFinite, length > 0 { duration = length }
        let size = item.presentationSize
        if size.width > 0, size.height > 0 { videoAspect = size.width / size.height }
        // Picture in Picture's own buttons can pause or play, so follow the player.
        isPlaying = player.timeControlStatus != .paused
    }

    private func itemDidEnd() {
        position = duration
        if loops {
            seek(to: 0)
            player.playImmediately(atRate: rate)
            return
        }
        recordPosition()
        if upNextPolicy.shouldAdvance(position: position, duration: duration, hasNext: next != nil,
                                      dismissed: upNextDismissed) {
            playNext()
        } else {
            isPlaying = false
            save()
        }
    }
}

extension PlayerModel: AVPictureInPictureControllerDelegate {
    /// Set before the app goes to the background, so the layer stays attached.
    func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
        isPictureInPictureActive = true
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        isPictureInPictureActive = true
        // Back to the library while the video floats. The model keeps the layer alive.
        isPlayerPresented = false
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        isPictureInPictureActive = false
    }

    func pictureInPictureController(_ controller: AVPictureInPictureController,
                                    failedToStartPictureInPictureWithError error: any Error) {
        isPictureInPictureActive = false
    }

    /// The person tapped "back to app" in the floating window: show the player again.
    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        isPlayerPresented = true
        completionHandler(true)
    }
}

extension Catalog {
    /// Media/Catalog.json from the app bundle.
    static var bundled: Catalog {
        guard let url = Bundle.main.url(forResource: "Catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? Catalog.decode(from: data) else {
            assertionFailure("Media/Catalog.json is missing or doesn't decode")
            return Catalog(shows: [])
        }
        return catalog
    }
}
