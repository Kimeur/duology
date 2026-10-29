import Foundation
import Observation
import os

/// Runs one summary at a time and owns its task. `NotesStore` holds the one service, above the
/// navigation stack and every layout decision, so opening, closing or folding the phone mid-way
/// never restarts or loses a summary: the views only read `draft` and `phase`.
///
/// Every request ends with a summary: the model's, or `SimpleSummary`'s when the model can't
/// run or fails. Stop is the only way to end without one.
@Observable
final class SummaryService {
    enum Phase: Equatable {
        case idle
        case working(Note.ID)
    }

    private(set) var phase = Phase.idle
    /// The summary so far, while `phase` is `.working`.
    private(set) var draft: DigestDraft?
    let engine: SummaryEngine

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let standInPace: Duration

    init(engine: SummaryEngine, standInPace: Duration = .milliseconds(150)) {
        self.engine = engine
        self.standInPace = standInPace
    }

    /// Nil when summaries will come from the on-device model; otherwise why they'll be simple.
    var unavailableReason: String? {
        switch engine {
        case .automatic: OnDeviceSummarizer.unavailableReason
        case .simple, .onDeviceAI, .standIn, .failing: nil
        }
    }

    func isWorking(on id: Note.ID) -> Bool { phase == .working(id) }

    /// Summarizes `note` as it is now and calls `finish` with the result. A new request replaces
    /// one still running; the replaced one never calls `finish`.
    func summarize(_ note: Note, finish: @escaping (Digest) -> Void) {
        task?.cancel()
        phase = .working(note.id)
        draft = DigestDraft()
        let source = Fingerprint.of(note.text)
        let budget = PromptBudget(note.text)
        let engine = engine
        let reason = unavailableReason
        task = Task { [weak self] in
            var digest: Digest?
            do {
                switch engine {
                case .automatic where reason != nil, .simple:
                    digest = SimpleSummary.digest(of: note, fallbackReason: reason)
                case .automatic, .onDeviceAI:
                    let result = try await OnDeviceSummarizer.summarize(budget.text) { self?.draft = $0 }
                    digest = result.finished(origin: .onDeviceAI, source: source, coversWholeNote: budget.isWhole)
                case .standIn:
                    for step in StandInStream.steps(toward: SimpleSummary.draft(of: note)) {
                        try await Task.sleep(for: self?.standInPace ?? .zero)
                        self?.draft = step
                    }
                    // Not the model's words, so saved as a simple summary.
                    digest = self?.draft?.finished(origin: .simple, source: source, coversWholeNote: budget.isWhole)
                case .failing:
                    try await Task.sleep(for: .seconds(1))
                    throw CocoaError(.featureUnsupported)
                }
            } catch is CancellationError {
                return
            } catch {
                // Any other failure, typed or not (the simulator's arrives as a plain NSError):
                // keep the feature working without AI. The error's domain and code are public in
                // the log; its description stays private, in case it ever quotes the note.
                if Task.isCancelled { return }
                let failure = error as NSError
                Self.log.error("Summary failed (\(failure.domain, privacy: .public) \(failure.code, privacy: .public)), using a simple one: \(String(describing: error), privacy: .private)")
                digest = nil
            }
            guard !Task.isCancelled, let self else { return }
            let result = digest ?? SimpleSummary.digest(of: note, fallbackReason: AppFacts.aiFailedReason)
            self.phase = .idle
            self.draft = nil
            self.task = nil
            if let result { finish(result) }
        }
    }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "notes", category: "summaries")

    /// Stops the summary in progress. The note keeps the summary it had before.
    func stop() {
        task?.cancel()
        task = nil
        phase = .idle
        draft = nil
    }
}
