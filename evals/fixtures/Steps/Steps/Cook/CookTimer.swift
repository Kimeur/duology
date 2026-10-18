import Combine
import Foundation

/// Counts down the minutes a step needs.
final class CookTimer: ObservableObject {
    @Published private(set) var secondsLeft = 0
    @Published private(set) var isRunning = false
    private var ticker: AnyCancellable?

    func set(minutes: Int) {
        pause()
        secondsLeft = minutes * 60
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    private func start() {
        guard secondsLeft > 0 else { return }
        isRunning = true
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func pause() {
        isRunning = false
        ticker = nil
    }

    private func tick() {
        secondsLeft = max(secondsLeft - 1, 0)
        if secondsLeft == 0 { pause() }
    }
}
