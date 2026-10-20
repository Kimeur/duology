import Foundation
import Observation

/// Holds the ledger, the selection and the filter for every view. It lives in RootView,
/// above the navigation stack and the panes, so opening, closing and rotating the phone
/// never lose what the person was looking at.
@Observable
final class FinanceModel {
    private(set) var ledger: Ledger
    /// The dashboard's "today". The sample data is pinned to 20 October 2026; pass `Date()`
    /// once real transactions flow in.
    let now: Date
    /// The transaction on show, in the trailing pane when open or pushed when closed.
    var selection: LedgerEntry.ID?
    /// Only this category in the activity list. Nil shows everything.
    var filter: Category?
    /// Two panes on the inner display. RootView sets it from the window's width class.
    var isTwoPane = false

    init(ledger: Ledger, now: Date) {
        self.ledger = ledger
        self.now = now
    }

    var currencyCode: String { ledger.currencyCode }
    var selectedTransaction: LedgerEntry? { selection.flatMap { ledger.transaction($0) } }
    var summary: MonthSummary { ledger.summary(now: now) }
    var pace: BudgetPace { ledger.budgetPace(now: now) }
    var daily: [DailySpend] { ledger.dailySpending(now: now) }
    var categories: [CategoryTotal] { ledger.categoryTotals(in: ledger.monthToDate(now)) }
    var sections: [DaySection] { ledger.sections(matching: filter, now: now) }

    func account(for transaction: LedgerEntry) -> Account? { ledger.account(transaction.accountID) }

    func history(for transaction: LedgerEntry) -> [MonthTotal] {
        ledger.merchantHistory(for: transaction.merchant, months: 6, now: now)
    }

    func setCategory(_ category: Category, for id: LedgerEntry.ID) {
        ledger.setCategory(category, for: id)
    }

    /// The navigation path when the phone is closed: the selection, pushed on the stack.
    /// Open, the trailing pane shows the selection, so the path stays empty. One source of
    /// truth, so closing the phone on a transaction shows that transaction, and opening it
    /// shows the transaction beside the list.
    var path: [LedgerEntry.ID] {
        get { isTwoPane ? [] : selection.map { [$0] } ?? [] }
        set {
            // Open, the stack can report its emptied path while it pops. Keep the selection.
            guard !isTwoPane else { return }
            selection = newValue.last
        }
    }
}
