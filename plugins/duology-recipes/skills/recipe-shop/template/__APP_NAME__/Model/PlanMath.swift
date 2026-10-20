import Foundation

/// Arithmetic for the plan cards. Prices are `Decimal`, as StoreKit's are.
nonisolated enum PlanMath {
    /// How much cheaper a year is than twelve months, in whole percent, rounded down so the
    /// card never claims more than the real saving. Nil when the year saves nothing.
    static func percentSaved(yearly: Decimal, monthly: Decimal) -> Int? {
        let twelve = monthly * 12
        guard twelve > 0, yearly < twelve else { return nil }
        var share = (twelve - yearly) / twelve * 100
        var whole = Decimal()
        NSDecimalRound(&whole, &share, 0, .down)
        let percent = NSDecimalNumber(decimal: whole).intValue
        return percent > 0 ? percent : nil
    }
}
