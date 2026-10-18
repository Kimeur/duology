import Combine
import Foundation

/// Records a walk. Distance is simulated so the app runs without location access.
final class Recorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var seconds = 0
    @Published private(set) var meters = 0.0
    @Published private(set) var laps: [Int] = []
    @Published var followsLocation = true
    private var ticker: AnyCancellable?

    func toggleRecording() {
        if isRecording {
            isRecording = false
            ticker = nil
        } else {
            isRecording = true
            ticker = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self else { return }
                    seconds += 1
                    meters += 1.3
                }
        }
    }

    func addLap() {
        guard isRecording else { return }
        laps.append(seconds)
    }

    var distanceText: String { String(format: "%.2f km", meters / 1000) }
    var timeText: String { String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) }
    var paceText: String {
        guard meters > 50 else { return "–" }
        let secondsPerKm = Double(seconds) / (meters / 1000)
        return String(format: "%d:%02d /km", Int(secondsPerKm) / 60, Int(secondsPerKm) % 60)
    }
}
