import SwiftUI

/// Launch switches for the UI tests, and for trying things by hand from the scheme.
/// Debug builds only: a Release build ignores every switch.
///
///   -uiTesting      animations off
///   -select N       open transaction N (the sample's ids start at 1, newest first in October)
///   -filter NAME    show one category in the activity list, for example -filter dining
enum LaunchOptions {
    #if DEBUG
    static let arguments = ProcessInfo.processInfo.arguments
    #else
    static let arguments: [String] = []
    #endif

    static var isUITesting: Bool { arguments.contains("-uiTesting") }

    static func configure() {
        if isUITesting {
            UIView.setAnimationsEnabled(false)
        }
    }

    /// The sample ledger, with any switches applied.
    static func makeModel() -> FinanceModel {
        // Gregorian, because the sample's dates are Gregorian. The person's time zone and
        // locale still apply, so days and weeks start where they expect.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = .current
        let model = FinanceModel(ledger: SampleLedger.make(calendar: calendar),
                                 now: SampleLedger.now(in: calendar))
        if let id = value(after: "-select").flatMap({ Int($0) }), model.ledger.transaction(id) != nil {
            model.selection = id
        }
        if let name = value(after: "-filter") {
            model.filter = Category(rawValue: name)
        }
        return model
    }

    /// The value after the last `name`, so a later switch overrides an earlier one.
    private static func value(after name: String) -> String? {
        guard let index = arguments.lastIndex(of: name), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
