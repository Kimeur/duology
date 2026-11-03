import Foundation

/// Photo or video.
nonisolated enum CaptureMode: String, CaseIterable, Codable, Sendable {
    case photo, video

    var title: String { self == .photo ? "Photo" : "Video" }
}

/// The self-timer's setting. Tapping it cycles off, 3 s, 10 s.
nonisolated enum TimerSetting: Int, CaseIterable, Codable, Sendable {
    case off = 0
    case three = 3
    case ten = 10

    var next: TimerSetting {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    var title: String { self == .off ? "Timer Off" : "\(rawValue)-Second Timer" }
    var shortTitle: String { self == .off ? "Off" : "\(rawValue)s" }
}

/// A self-timer counting down to the shutter, one second at a time. The store calls `tick()`
/// once a second; when it returns true the shutter fires. Shown large on the preview and on the
/// outer display, so the person in front of the camera can read it from across the room.
nonisolated struct Countdown: Equatable, Sendable {
    let total: Int
    private(set) var left: Int

    init(seconds: Int) {
        total = max(1, seconds)
        left = total
    }

    /// One second passed. True when the countdown reaches zero: time to fire.
    mutating func tick() -> Bool {
        guard left > 0 else { return false }
        left -= 1
        return left == 0
    }

    var isDone: Bool { left == 0 }
}

/// The recording time, as the photographer and the subject see it: "0:07", "1:05", "1:00:00".
nonisolated enum RecordingClock {
    static func text(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded(.down)))
        let (hours, minutes, secs) = (whole / 3600, (whole % 3600) / 60, whole % 60)
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// The same, for VoiceOver: "1 minute 5 seconds".
    static func spoken(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded(.down)))
        let minutes = whole / 60, secs = whole % 60
        let parts = [minutes > 0 ? "\(minutes) minute\(minutes == 1 ? "" : "s")" : nil,
                     secs > 0 || minutes == 0 ? "\(secs) second\(secs == 1 ? "" : "s")" : nil]
        return parts.compactMap { $0 }.joined(separator: " ")
    }
}

/// Whether the app may use the camera, and what to tell people when it may not. The capture
/// layer maps AVFoundation's authorization status to this.
nonisolated enum CameraAccess: String, Sendable {
    case notDetermined, authorized, denied, restricted
    /// No camera on this device: the simulator. The stand-in camera takes over.
    case noCamera

    /// Nil when the studio can show a live preview; otherwise the line to show instead.
    var message: String? {
        switch self {
        case .authorized, .notDetermined: nil
        case .denied: "Camera access is off for this app. Turn it on in Settings to use the studio."
        case .restricted: "The camera is restricted on this device, for example by Screen Time."
        case .noCamera: "No camera here. The studio uses a stand-in so you can try every pose."
        }
    }

    /// Settings can change this; the other states can't be fixed there.
    var opensSettings: Bool { self == .denied }
}
