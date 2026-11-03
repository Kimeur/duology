import CoreGraphics
import Foundation

/// Facts about this app that more than one file needs.
nonisolated enum AppFacts {
    /// The stand-in camera's frame size: 4:3, like a photo from the rear camera.
    static let standInSize = CGSize(width: 1200, height: 900)
    /// The stand-in video's frame size and rate. Small, so the simulator writes it quickly.
    static let standInVideoSize = CGSize(width: 640, height: 480)
    static let standInFrameRate: Int32 = 15

    /// Shown on the outer display when there is nothing to count or record.
    static let subjectReadyLine = "Look here"
    /// Said to the photographer about the outer display, in the controls.
    static let subjectViewTitle = "Subject View"

    /// Where the gallery keeps its files, inside the app's Documents folder.
    static let capturesFolder = "Captures"
    static let indexFile = "Captures.json"
}
