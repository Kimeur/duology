import SwiftUI

/// Launch switches for the UI tests, and for trying things by hand from the scheme.
/// Debug builds only: a Release build ignores every switch.
///
///   -uiTesting         animations off, test markers on
///   -resetState        delete every photo and video in the gallery
///   -standIn           use the stand-in camera even on a device with a camera
///   -mode NAME         start in photo or video mode
///   -timer SECONDS     start with the self-timer at 3 or 10 seconds
///   -shutter           press the shutter once at launch (with -timer: start the countdown),
///                      for screenshots of the countdown on both displays
enum LaunchOptions {
    #if DEBUG
    static let arguments = ProcessInfo.processInfo.arguments
    #else
    static let arguments: [String] = []
    #endif

    static var isUITesting: Bool { arguments.contains("-uiTesting") }
    static var resetsState: Bool { arguments.contains("-resetState") }
    static var forcesStandIn: Bool { arguments.contains("-standIn") }

    static func configure() {
        if isUITesting {
            UIView.setAnimationsEnabled(false)
        }
    }

    static func apply(to store: StudioStore) {
        if let mode = value("-mode").flatMap(CaptureMode.init(rawValue:)) {
            store.setMode(mode)
        }
        if let timer = value("-timer").flatMap(Int.init).flatMap(TimerSetting.init(rawValue:)) {
            store.timer = timer
        }
        if arguments.contains("-shutter") {
            store.shutter()
        }
    }

    /// The word after the last `name`, so a later switch overrides an earlier one.
    private static func value(_ name: String) -> String? {
        guard let index = arguments.lastIndex(of: name), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
