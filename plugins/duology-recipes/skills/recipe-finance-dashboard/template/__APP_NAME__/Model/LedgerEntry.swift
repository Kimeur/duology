import Foundation

/// What a transaction was for. The view layer adds colours (`Category+Style.swift`).
nonisolated enum Category: String, CaseIterable, Identifiable, Sendable {
    case groceries, dining, transport, shopping, health, entertainment, travel
    case housing, utilities, subscriptions
    case income, transfer

    /// How a category counts in the totals.
    enum Kind: Sendable {
        /// Day-to-day spending. The monthly budget covers these.
        case everyday
        /// Fixed bills: rent, energy, phone. Spending, but outside the budget.
        case bill
        case income
        /// Money moving between your own accounts. Never spending or income.
        case transfer
    }

    var id: String { rawValue }

    var kind: Kind {
        switch self {
        case .housing, .utilities, .subscriptions: .bill
        case .income: .income
        case .transfer: .transfer
        default: .everyday
        }
    }

    var isSpending: Bool { kind == .everyday || kind == .bill }

    var name: String {
        switch self {
        case .groceries: "Groceries"
        case .dining: "Eating out"
        case .transport: "Transport"
        case .shopping: "Shopping"
        case .health: "Health"
        case .entertainment: "Entertainment"
        case .travel: "Travel"
        case .housing: "Housing"
        case .utilities: "Utilities"
        case .subscriptions: "Subscriptions"
        case .income: "Income"
        case .transfer: "Transfer"
        }
    }

    /// SF Symbol name.
    var symbol: String {
        switch self {
        case .groceries: "cart.fill"
        case .dining: "fork.knife"
        case .transport: "tram.fill"
        case .shopping: "bag.fill"
        case .health: "cross.case.fill"
        case .entertainment: "ticket.fill"
        case .travel: "airplane"
        case .housing: "house.fill"
        case .utilities: "bolt.fill"
        case .subscriptions: "play.rectangle.fill"
        case .income: "arrow.down.left"
        case .transfer: "arrow.left.arrow.right"
        }
    }

    /// Categories a person can move a spending transaction to.
    static let spending: [Category] = allCases.filter(\.isSpending)
}

nonisolated struct Account: Identifiable, Hashable, Sendable {
    enum Kind: Sendable {
        case current, savings, credit
    }

    let id: String
    var name: String
    var kind: Kind
    /// Today's balance. A credit card's is negative: money owed.
    var balance: Money
}

/// One transaction. Not called `Transaction`, so it doesn't hide SwiftUI's `Transaction`
/// (the one `withTransaction` and `.transaction(_:)` take) anywhere in the app.
nonisolated struct LedgerEntry: Identifiable, Hashable, Sendable {
    let id: Int
    var date: Date
    var merchant: String
    var category: Category
    /// Negative for money out, positive for money in.
    var amount: Money
    var accountID: Account.ID
    var place: String?
    var note: String?
    /// Card payments the bank hasn't settled yet.
    var isPending = false
}
