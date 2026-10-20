import Foundation

/// Every number the dashboard shows, worked out from accounts and transactions.
///
/// Foundation only, `nonisolated` and `Sendable`, so Tools/run-model-tests.sh checks it on
/// the Mac in seconds. Functions that depend on the date take `now`; nothing reads the clock.
nonisolated struct Ledger: Equatable, Sendable {
    var accounts: [Account]
    /// Newest first.
    private(set) var transactions: [LedgerEntry]
    /// The monthly budget for everyday spending. Bills sit outside it.
    var monthlyBudget: Money
    /// ISO 4217 code for every amount in this ledger, for example "EUR".
    var currencyCode: String
    var calendar: Calendar

    init(accounts: [Account], transactions: [LedgerEntry], monthlyBudget: Money,
         currencyCode: String, calendar: Calendar) {
        self.accounts = accounts
        self.transactions = Self.newestFirst(transactions)
        self.monthlyBudget = monthlyBudget
        self.currencyCode = currencyCode
        self.calendar = calendar
    }

    private static func newestFirst(_ list: [LedgerEntry]) -> [LedgerEntry] {
        list.sorted { $0.date == $1.date ? $0.id > $1.id : $0.date > $1.date }
    }

    // MARK: Lookups

    /// The sum of every account. A credit card's balance counts against it.
    var balance: Money { accounts.map(\.balance).sum() }

    func account(_ id: Account.ID) -> Account? { accounts.first { $0.id == id } }
    func transaction(_ id: LedgerEntry.ID) -> LedgerEntry? { transactions.first { $0.id == id } }

    /// Moves a transaction to another category. Returns false when the id is unknown.
    @discardableResult
    mutating func setCategory(_ category: Category, for id: LedgerEntry.ID) -> Bool {
        guard let index = transactions.firstIndex(where: { $0.id == id }) else { return false }
        transactions[index].category = category
        return true
    }

    // MARK: Periods

    /// The calendar month that contains `date`: from its first instant up to, not including,
    /// the next month's.
    func month(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
    }

    /// From the start of `now`'s month to the end of `now`'s day.
    func monthToDate(_ now: Date) -> DateInterval {
        let month = month(containing: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return DateInterval(start: month.start, end: min(tomorrow, month.end))
    }

    /// Every interval here is half open: it holds its start, not its end. (`DateInterval.contains`
    /// holds both, so a transaction at midnight on the 1st would count in two months.)
    private func transactions(in interval: DateInterval) -> [LedgerEntry] {
        transactions.filter { $0.date >= interval.start && $0.date < interval.end }
    }

    // MARK: Totals

    /// Money spent in `interval`, as a positive amount. A refund in a spending category
    /// lowers it. Transfers and income never count.
    func spent(in interval: DateInterval, kinds: Set<Category.Kind> = [.everyday, .bill]) -> Money {
        -transactions(in: interval)
            .filter { kinds.contains($0.category.kind) }
            .map(\.amount)
            .sum()
    }

    /// Income in `interval`, as a positive amount.
    func received(in interval: DateInterval) -> Money {
        transactions(in: interval)
            .filter { $0.category.kind == .income }
            .map(\.amount)
            .sum()
    }

    /// Month to date: what came in, what went out, and how that splits between everyday
    /// spending and bills.
    func summary(now: Date) -> MonthSummary {
        let period = monthToDate(now)
        return MonthSummary(moneyIn: received(in: period),
                            everyday: spent(in: period, kinds: [.everyday]),
                            bills: spent(in: period, kinds: [.bill]))
    }

    /// Spending per category in `interval`, largest first. Categories with nothing spent, or
    /// more refunded than spent, are left out, and the shares of those shown add up to one.
    func categoryTotals(in interval: DateInterval) -> [CategoryTotal] {
        let items = transactions(in: interval)
        let totals = Category.spending
            .map { category in
                let mine = items.filter { $0.category == category }
                return CategoryTotal(category: category, total: -mine.map(\.amount).sum(),
                                     count: mine.count, share: 0)
            }
            .filter { $0.total > .zero }
        let whole = totals.map(\.total).sum()
        return totals
            .map { item in
                var item = item
                item.share = item.total.fraction(of: whole)
                return item
            }
            .sorted { $0.total == $1.total ? $0.category.name < $1.category.name : $0.total > $1.total }
    }

    // MARK: Budget

    /// Everyday spending so far this month against an even pace through the month.
    func budgetPace(now: Date) -> BudgetPace {
        let interval = month(containing: now)
        let days = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let today = calendar.component(.day, from: now)
        return BudgetPace(budget: monthlyBudget,
                          spent: spent(in: monthToDate(now), kinds: [.everyday]),
                          elapsedDays: min(max(today, 1), days),
                          daysInMonth: days,
                          monthStart: interval.start)
    }

    /// Cumulative everyday spending at the end of each day of `now`'s month, from day 1 to today.
    func dailySpending(now: Date) -> [DailySpend] {
        let pace = budgetPace(now: now)
        var running = Money.zero
        return (1...pace.elapsedDays).map { day in
            let start = calendar.date(byAdding: .day, value: day - 1, to: pace.monthStart) ?? pace.monthStart
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            running = running + spent(in: DateInterval(start: start, end: end), kinds: [.everyday])
            return DailySpend(day: day, cumulative: running)
        }
    }

    // MARK: Activity

    /// Transactions grouped by day, newest first, optionally only one category.
    func sections(matching filter: Category?, now: Date) -> [DaySection] {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var result: [DaySection] = []
        for item in transactions where filter == nil || item.category == filter {
            let day = calendar.startOfDay(for: item.date)
            if result.last?.day == day {
                result[result.count - 1].transactions.append(item)
            } else {
                let label: DaySection.Label = day == today ? .today : day == yesterday ? .yesterday : .date(day)
                result.append(DaySection(day: day, label: label, transactions: [item]))
            }
        }
        return result
    }

    /// What was spent at `merchant` in each of the last `months` calendar months, oldest
    /// first, including `now`'s month. Months with nothing spent are zero.
    func merchantHistory(for merchant: String, months: Int, now: Date) -> [MonthTotal] {
        let current = month(containing: now).start
        return (0..<max(1, months)).reversed().map { back in
            let start = calendar.date(byAdding: .month, value: -back, to: current) ?? current
            let interval = month(containing: start)
            let total = -transactions(in: interval)
                .filter { $0.merchant == merchant && $0.category.isSpending }
                .map(\.amount)
                .sum()
            return MonthTotal(monthStart: start, total: total)
        }
    }
}

// MARK: - Results

nonisolated struct MonthSummary: Equatable, Sendable {
    var moneyIn: Money
    var everyday: Money
    var bills: Money
    var moneyOut: Money { everyday + bills }
}

nonisolated struct CategoryTotal: Identifiable, Equatable, Sendable {
    var category: Category
    /// Positive.
    var total: Money
    var count: Int
    /// Share of all spending in the period, 0...1.
    var share: Double
    var id: Category { category }
}

nonisolated struct DailySpend: Identifiable, Equatable, Sendable {
    var day: Int
    var cumulative: Money
    var id: Int { day }
}

nonisolated struct MonthTotal: Identifiable, Equatable, Sendable {
    var monthStart: Date
    var total: Money
    var id: Date { monthStart }
}

nonisolated struct DaySection: Identifiable, Equatable, Sendable {
    enum Label: Equatable, Sendable {
        case today, yesterday
        case date(Date)
    }

    var day: Date
    var label: Label
    var transactions: [LedgerEntry]
    var id: Date { day }
}

nonisolated struct BudgetPace: Equatable, Sendable {
    var budget: Money
    /// Everyday spending, month to date. Positive.
    var spent: Money
    /// Days of the month so far, today included.
    var elapsedDays: Int
    var daysInMonth: Int
    var monthStart: Date

    /// Where an even pace would be at the end of `day`.
    func pace(atDay day: Int) -> Money {
        budget.scaled(by: Double(day) / Double(max(daysInMonth, 1)))
    }

    /// Where an even pace would be by the end of today.
    var expected: Money { pace(atDay: elapsedDays) }
    var remaining: Money { budget - spent }
    /// How far under the even pace, or over it when negative.
    var margin: Money { expected - spent }
    var isOverPace: Bool { spent > expected }
    var isOverBudget: Bool { spent > budget }
    /// The month's total if spending carries on at today's rate.
    var projected: Money { spent.scaled(by: Double(daysInMonth) / Double(max(elapsedDays, 1))) }
}
