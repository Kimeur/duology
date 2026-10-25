import Foundation
import Observation

/// The activities, the child's progress, the navigation path, the parental gate and the
/// speaker. `RootView` owns the one store, above the navigation stack and every layout
/// decision, so opening, closing and folding the phone never lose a star, a question or a
/// half-typed gate answer. Progress is saved on this device on every change.
@Observable
final class LearningStore {
    let activities: [Activity]
    private(set) var progress: Progress
    /// The navigation stack's path: the activity on screen, if any.
    var path: [Activity.ID] = []
    /// Read each new question aloud when it appears. Set in the grown-ups area.
    var readsAloud: Bool {
        didSet { defaults.set(readsAloud, forKey: Self.readAloudKey) }
    }

    // The parental gate and the grown-ups area behind it.
    var isGateOpen = false
    private(set) var gate: ParentalGate
    private(set) var gatePassed = false

    let speaker: Speaker

    @ObservationIgnored private let defaults: UserDefaults

    init(activities: [Activity], defaults: UserDefaults = .standard, gateSeed: UInt64, speaker: Speaker) {
        self.activities = activities
        self.defaults = defaults
        self.speaker = speaker
        gate = ParentalGate(seed: gateSeed)
        if let data = defaults.data(forKey: Self.progressKey),
           let saved = try? JSONDecoder().decode(Progress.self, from: data) {
            progress = saved
        } else {
            progress = Progress()
        }
        readsAloud = defaults.object(forKey: Self.readAloudKey) as? Bool ?? true
    }

    /// The store the app starts with: the sample activities, then the launch switches.
    static func launch() -> LearningStore {
        let store = LearningStore(activities: SampleActivities.all, gateSeed: LaunchOptions.gateSeed,
                                  speaker: Speaker(isMuted: LaunchOptions.isUITesting))
        LaunchOptions.apply(to: store)
        return store
    }

    func activity(_ id: Activity.ID) -> Activity? {
        activities.first { $0.id == id }
    }

    // MARK: Learning

    func open(_ activity: Activity) {
        path = [activity.id]
    }

    func pick(_ answer: Answer, in activity: Activity) -> Progress.Pick {
        let result = progress.pick(answer.id, in: activity)
        if result != .ignored { save() }
        return result
    }

    func next(in activity: Activity) {
        progress.next(in: activity)
        save()
    }

    func playAgain(_ activity: Activity) {
        progress.playAgain(activity)
        save()
    }

    func jump(to question: Int, in activity: Activity) {
        progress.jump(to: question, in: activity)
        save()
    }

    func resetProgress() {
        progress.reset()
        save()
    }

    // MARK: The parental gate

    /// Shows the gate with an empty entry. The grown-ups area stays locked until it passes.
    func openGate() {
        gate.cancel()
        gatePassed = false
        isGateOpen = true
    }

    func typeGateDigit(_ digit: Int) {
        gate.type(digit)
    }

    func deleteGateDigit() {
        gate.deleteLast()
    }

    /// A right answer opens the grown-ups area; a wrong one closes the gate.
    func checkGate() {
        switch gate.check() {
        case .passed: gatePassed = true
        case .failed: closeGate()
        case .notReady: break
        }
    }

    /// Closes the gate or the grown-ups area. The next opening asks again.
    func closeGate() {
        isGateOpen = false
        gatePassed = false
        gate.cancel()
    }

    // MARK: Saving

    private func save() {
        if let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: Self.progressKey)
        }
    }

    private static let progressKey = "progress"
    private static let readAloudKey = "readsAloud"
}
