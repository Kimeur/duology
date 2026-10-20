// Model tests. They build __APP_NAME__/Model/*.swift with this file and run on the Mac.
// Run from the project folder: Tools/run-model-tests.sh
import Foundation

var failures = 0
var passes = 0

func check(_ ok: Bool, _ message: String) {
    if ok {
        passes += 1
        print("ok   \(message)")
    } else {
        failures += 1
        print("FAIL \(message)")
    }
}

func near(_ a: CGFloat, _ b: CGFloat, _ tolerance: CGFloat = 0.01) -> Bool { abs(a - b) <= tolerance }

/// UTC, so the checks give the same answer in every time zone.
var utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

func date(_ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    utc.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}

let now = date(10, 20, 18, 40)

func item(_ id: Int, _ when: Date, _ merchant: String, _ category: Category, _ amount: Money,
          account: String = "current") -> LedgerEntry {
    LedgerEntry(id: id, date: when, merchant: merchant, category: category, amount: amount, accountID: account)
}

let accounts = [
    Account(id: "current", name: "Everyday", kind: .current, balance: 1_000.00),
    Account(id: "credit", name: "Credit card", kind: .credit, balance: -250.50),
]

let small = Ledger(accounts: accounts, transactions: [
    item(1, date(10, 1, 0, 0), "Rent", .housing, -900),
    item(2, date(10, 2), "Market", .groceries, -40.25),
    item(3, date(10, 19), "Market", .groceries, -20.00),
    item(4, date(10, 20, 9), "Café", .dining, -4.50),
    item(5, date(10, 20, 10), "Shop", .shopping, 10.00),       // a refund
    item(6, date(10, 8), "Client", .income, 500),
    item(7, date(10, 12), "To savings", .transfer, -300),
    item(8, date(11, 1, 0, 0), "Next month", .groceries, -99),  // the first instant of November
    item(9, date(9, 30, 23, 59), "Last month", .groceries, -11),
    item(10, date(9, 15), "Market", .groceries, -30.00),
    item(11, date(6, 3), "Market", .groceries, -12.00),
], monthlyBudget: 310, currencyCode: "EUR", calendar: utc)

// MARK: Money

check(Money(floatLiteral: 12.34).cents == 1234 && Money(integerLiteral: 3).cents == 300, "literals are exact cents")
check(Money(floatLiteral: 0.1) + Money(floatLiteral: 0.2) == Money(floatLiteral: 0.3), "0.1 + 0.2 is 0.3 in money")
check([Money(floatLiteral: 1.10), 2.20, -0.30].sum() == Money(floatLiteral: 3.00), "sum() adds cents")
check((-Money(floatLiteral: 8.40)).magnitude == Money(floatLiteral: 8.40), "magnitude drops the sign")
check(Money(floatLiteral: 50).fraction(of: 200) == 0.25 && Money(floatLiteral: 5).fraction(of: .zero) == 0,
      "fraction of a whole, and zero for a zero whole")
check(Money(floatLiteral: 1_400).scaled(by: 20.0 / 31.0) == Money(floatLiteral: 903.23), "scaled rounds to the cent")

// MARK: Ledger basics

check(small.transactions.map(\.id) == [8, 5, 4, 3, 7, 6, 2, 1, 9, 10, 11], "transactions are newest first")
check(small.balance == Money(floatLiteral: 749.50), "balance adds every account, the card's debt included")
let october = small.month(containing: now)
check(october.start == date(10, 1, 0, 0) && october.end == date(11, 1, 0, 0), "a month runs from the 1st to the next 1st")
check(small.monthToDate(now).end == date(10, 21, 0, 0), "month to date runs to the end of today")
check(small.spent(in: october) == Money(floatLiteral: 954.75),
      "spending counts bills and everyday, minus refunds; not income, transfers or other months")
check(small.spent(in: october, kinds: [.everyday]) == Money(floatLiteral: 54.75), "everyday only leaves the rent out")
check(small.received(in: october) == 500, "income in the month")
check(small.spent(in: small.month(containing: date(9, 10))) == Money(floatLiteral: 41.00),
      "a payment one minute before midnight on the 30th stays in September")

let summary = small.summary(now: now)
check(summary.moneyIn == 500 && summary.everyday == Money(floatLiteral: 54.75) && summary.bills == 900
      && summary.moneyOut == Money(floatLiteral: 954.75), "month summary: in, everyday, bills, out")

// MARK: Categories

let categories = small.categoryTotals(in: small.monthToDate(now))
check(categories.map(\.category) == [.housing, .groceries, .dining], "categories largest first, empty and refunded-to-zero left out")
check(categories.first?.total == 900 && categories.first?.count == 1, "a category's total and count")
check(abs(categories.map(\.share).reduce(0, +) - 1) < 0.0001, "shares add up to one")
check(!categories.contains { $0.category == .income || $0.category == .transfer }, "income and transfers are not spending")

// MARK: Budget pace

let pace = small.budgetPace(now: now)
check(pace.daysInMonth == 31 && pace.elapsedDays == 20, "October has 31 days; the 20th is day 20")
check(pace.expected == Money(floatLiteral: 200.00), "an even pace: 310 over 31 days is 200 by day 20")
check(pace.margin == Money(floatLiteral: 145.25) && !pace.isOverPace, "under pace by the difference")
check(pace.remaining == Money(floatLiteral: 255.25) && !pace.isOverBudget, "budget left")
check(pace.projected == Money(floatLiteral: 84.86), "projection at today's rate")
check(pace.pace(atDay: 0) == .zero && pace.pace(atDay: 31) == 310, "the pace line runs from zero to the budget")
var tight = small
tight.monthlyBudget = 60
check(tight.budgetPace(now: now).isOverPace && !tight.budgetPace(now: now).isOverBudget,
      "over pace before over budget")

let daily = small.dailySpending(now: now)
check(daily.count == 20 && daily.first?.day == 1 && daily.last?.day == 20, "one point per day so far")
check(daily.last?.cumulative == pace.spent, "the last point is everyday spending so far")
check(daily[1].cumulative == Money(floatLiteral: 40.25) && daily[18].cumulative == Money(floatLiteral: 60.25),
      "points add up day by day")

// MARK: Activity

let sections = small.sections(matching: nil, now: now)
check(sections.first?.day == utc.startOfDay(for: date(11, 1)), "a future-dated payment gets its own day")
check(sections.contains { $0.label == .today && $0.transactions.map(\.id) == [5, 4] }, "today's group, newest first")
check(sections.contains { $0.label == .yesterday && $0.transactions.map(\.id) == [3] }, "yesterday's group")
check(sections.map(\.transactions.count).reduce(0, +) == 11, "every transaction lands in one group")
let groceries = small.sections(matching: .groceries, now: now)
check(groceries.allSatisfy { $0.transactions.allSatisfy { $0.category == .groceries } }
      && groceries.map(\.transactions.count).reduce(0, +) == 6, "a filter keeps one category")

let history = small.merchantHistory(for: "Market", months: 6, now: now)
check(history.count == 6 && history.first?.monthStart == date(5, 1, 0, 0) && history.last?.monthStart == date(10, 1, 0, 0),
      "six months of history, oldest first, this month last")
check(history.map(\.total) == [0, 12, 0, 0, 30, Money(floatLiteral: 60.25)], "months with nothing are zero")

var moved = small
check(moved.setCategory(.dining, for: 2) && moved.transaction(2)?.category == .dining, "a transaction changes category")
check(moved.categoryTotals(in: moved.monthToDate(now)).first { $0.category == .dining }?.total == Money(floatLiteral: 44.75),
      "and its amount moves to the new category")
check(!moved.setCategory(.dining, for: 999), "an unknown id changes nothing")

// MARK: The sample data

let sample = SampleLedger.make(calendar: utc)
let sampleNow = SampleLedger.now(in: utc)
check(Set(sample.transactions.map(\.id)).count == sample.transactions.count, "sample ids are unique")
check(sample.transactions.allSatisfy { $0.date <= sampleNow }, "no sample transaction is in the future")
check(sample.transactions.allSatisfy { sample.account($0.accountID) != nil }, "every sample transaction has an account")
check(sample.balance == Money(floatLiteral: 11_108.91), "sample balance")
let sampleSummary = sample.summary(now: sampleNow)
check(sampleSummary.everyday == Money(floatLiteral: 776.49), "sample everyday spending in October")
check(sampleSummary.bills == Money(floatLiteral: 1_316.15), "sample bills in October")
check(sampleSummary.moneyIn == Money(floatLiteral: 620.00), "sample income in October")
check(sample.budgetPace(now: sampleNow).margin == Money(floatLiteral: 126.74), "sample is under an even pace")
check(sample.sections(matching: nil, now: sampleNow).first?.label == .today, "the sample starts today")
check(sample.merchantHistory(for: "Harbor Market", months: 6, now: sampleNow).allSatisfy { $0.total > .zero },
      "a weekly shop shows in every month of the history")

// MARK: Panes on the fold

// Numbers from duo-design-system's worked example: an 847 pt grid on the open phone with
// the fold's frame at 435 to 475 in the grid's coordinates (measured on the simulator).
let flatFold = DuoFold(minX: 435, maxX: 475, isActive: false)
let bentFold = DuoFold(minX: 435, maxX: 475, isActive: true)

let none = PaneFrames(width: 847, count: 8, gutter: 16, fold: nil)
check(none.map { near($0.leading.width, $0.trailing.width) && near($0.gap, 16) } == true,
      "no fold: two equal panes and one gutter")
let flat = PaneFrames(width: 847, count: 8, gutter: 16, fold: flatFold)
check(flat.map { near($0.leading.x, 0) && near($0.leading.maxX, 447) && near($0.trailing.x, 463) && near($0.trailing.maxX, 847) } == true,
      "flat: the panes meet at one gutter centred on the fold line")
let bent = PaneFrames(width: 847, count: 8, gutter: 16, fold: bentFold)
check(bent.map { near($0.leading.maxX, 435) && near($0.trailing.x, 475) && near($0.gap, 40) } == true,
      "partly folded: the gap is the fold's frame")
if let flat, let bent {
    check(abs(flat.leading.maxX - bent.leading.maxX) <= 12 && abs(flat.trailing.x - bent.trailing.x) <= 12,
          "folding moves each pane edge 12 pt or less")
    check(near(flat.leading.x, bent.leading.x) && near(flat.trailing.maxX, bent.trailing.maxX),
          "folding keeps the outer margins")
}
let odd = PaneFrames(width: 847, count: 7, gutter: 16, fold: bentFold)
check(odd.map { near($0.leading.maxX, 435) && near($0.trailing.x, 475) } == true, "an odd count rounds down to even")
let edge = PaneFrames(width: 400, count: 8, gutter: 12, fold: DuoFold(minX: 5, maxX: 45, isActive: true))
check(edge.map { $0.leading.x >= 45 && $0.trailing.x > $0.leading.maxX } == true,
      "a fold near the edge: both panes go on the wide side")
check(PaneFrames(width: 0, count: 8, gutter: 16, fold: nil) == nil, "no panes before the first layout pass")
let columns = DuoColumns(width: 847, count: 8, gutter: 16, fold: bentFold)
check(columns.columns.count == 8 && columns.split == 4, "eight columns, four on each side")
check(!columns.columns.contains { $0.x < 475 && $0.maxX > 435 }, "no column touches the fold")

// MARK: Concurrency

// The app target compiles with default main actor isolation. Here the model runs off the
// main actor, and the check calls a method, a computed property or == on every model type,
// so a type that loses `nonisolated` stops this build. Add a line for each new type.
let calendar = utc
let offMain = await Task.detached { () -> Bool in
    let ledger = SampleLedger.make(calendar: calendar)                       // SampleLedger
    let today = SampleLedger.now(in: calendar)
    let account = ledger.account("current")                                  // Ledger
    let kindMatches = account?.kind == .current                              // Account.Kind ==
    let accountMatches = account == ledger.accounts.first                    // Account ==
    let category = Category.groceries
    let everyday = category.kind == .everyday && category.isSpending          // Category
    let transaction = ledger.transaction(1)
    let sameEntry = transaction == ledger.transactions.first { $0.id == 1 }  // LedgerEntry ==
    let summary = ledger.summary(now: today).moneyOut > .zero                // MonthSummary, Money
    let totals = ledger.categoryTotals(in: ledger.monthToDate(today)).first?.id == .housing // CategoryTotal
    let days = ledger.dailySpending(now: today).last?.id == 20               // DailySpend
    let months = ledger.merchantHistory(for: "Harbor Market", months: 3, now: today).last?.id
        == ledger.month(containing: today).start                             // MonthTotal
    let section = ledger.sections(matching: nil, now: today).first
    let today2 = section?.id == calendar.startOfDay(for: today) && section?.label == .today // DaySection
    let pace = ledger.budgetPace(now: today).expected > .zero               // BudgetPace
    let money = [Money(cents: 1), Money(cents: 2)].sum() == Money(cents: 3)  // Money, Sequence.sum
    let fold = DuoFold(minX: 1, maxX: 2, isActive: false)
    let folds = fold == DuoFold(minX: 1, maxX: 2, isActive: false)          // DuoFold ==
    let grid = DuoColumns(width: 100, count: 4, gutter: 4, fold: nil)
    let column = grid.columns.first?.maxX == 22                               // DuoColumns, Column
    let panes = PaneFrames(width: 100, count: 4, gutter: 4, fold: nil)?.gap == 4 // PaneFrames
    return kindMatches && accountMatches && everyday && sameEntry && summary && totals && days
        && months && today2 && pace && money && folds && column && panes
}.value
check(offMain, "the model runs off the main actor")

print("\n\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
