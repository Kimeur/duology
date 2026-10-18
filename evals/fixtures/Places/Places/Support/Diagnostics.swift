import UIKit

/// Text for bug reports. Not used for layout.
enum Diagnostics {
    @MainActor
    static var deviceSummary: String {
        let device = UIDevice.current
        return "\(device.model), iOS \(device.systemVersion), scale \(UIScreen.main.scale)"
    }
}
