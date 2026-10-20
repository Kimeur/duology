import Foundation

/// An amount of money in minor units (cents), so sums are exact. Negative means money out.
///
/// The currency lives in `Ledger.currencyCode`, not here: one ledger, one currency.
/// Views format with `.currency(code:)`, which follows the person's locale.
nonisolated struct Money: Hashable, Comparable, Sendable, AdditiveArithmetic,
                          ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    var cents: Int

    init(cents: Int) {
        self.cents = cents
    }

    /// `42` is 42.00.
    init(integerLiteral value: Int) {
        cents = value * 100
    }

    /// `-12.5` is -12.50. Rounded to the nearest cent, so literals with two decimals are exact.
    init(floatLiteral value: Double) {
        cents = Int((value * 100).rounded())
    }

    static let zero = Money(cents: 0)

    static func + (lhs: Money, rhs: Money) -> Money { Money(cents: lhs.cents + rhs.cents) }
    static func - (lhs: Money, rhs: Money) -> Money { Money(cents: lhs.cents - rhs.cents) }
    static prefix func - (value: Money) -> Money { Money(cents: -value.cents) }
    static func < (lhs: Money, rhs: Money) -> Bool { lhs.cents < rhs.cents }

    /// The size of the amount, without its sign.
    var magnitude: Money { Money(cents: abs(cents)) }
    var isNegative: Bool { cents < 0 }

    /// For `Text(_:format: .currency(code:))` and for charts.
    var decimal: Decimal { Decimal(cents) / 100 }
    /// For chart axes only. Never add Doubles up for totals; add Money.
    var doubleValue: Double { Double(cents) / 100 }

    /// `self` as a fraction of `whole`, from 0. Zero when `whole` is zero.
    func fraction(of whole: Money) -> Double {
        whole.cents == 0 ? 0 : Double(cents) / Double(whole.cents)
    }

    /// `self` times a fraction, rounded to the cent.
    func scaled(by factor: Double) -> Money {
        Money(cents: Int((Double(cents) * factor).rounded()))
    }
}

extension Sequence where Element == Money {
    nonisolated func sum() -> Money { reduce(.zero, +) }
}
