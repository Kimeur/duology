import Foundation

/// Sample accounts and six months of transactions, so the app has something real to show.
///
/// The sample is pinned to 20 October 2026, 18:40, in the calendar's time zone, so screenshots
/// and tests always show the same month. Replace this file with your own data source, and
/// pass `Date()` as `now` once real transactions flow in.
nonisolated enum SampleLedger {
    static func now(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 18, minute: 40)) ?? Date()
    }

    static func make(calendar: Calendar) -> Ledger {
        Ledger(accounts: accounts,
               transactions: transactions(calendar: calendar),
               monthlyBudget: 1_400,
               currencyCode: "EUR",
               calendar: calendar)
    }

    static let accounts = [
        Account(id: "current", name: "Everyday", kind: .current, balance: 2_481.36),
        Account(id: "savings", name: "Savings", kind: .savings, balance: 8_940.00),
        Account(id: "credit", name: "Credit card", kind: .credit, balance: -312.45),
    ]

    /// One line of sample data. `month` is 0 for October 2026, -1 for September, and so on.
    private struct Line {
        var month: Int
        var day: Int
        var hour: Int
        var merchant: String
        var category: Category
        var amount: Money
        var account = "current"
        var place: String?
        var note: String?
        var isPending = false
    }

    static func transactions(calendar: Calendar) -> [LedgerEntry] {
        let lines = october + earlierMonths
        return lines.enumerated().compactMap { index, line in
            guard let date = calendar.date(from: DateComponents(year: 2026, month: 10 + line.month,
                                                                day: line.day, hour: line.hour,
                                                                minute: (index * 7) % 60))
            else { return nil }
            return LedgerEntry(id: index + 1, date: date, merchant: line.merchant, category: line.category,
                               amount: line.amount, accountID: line.account, place: line.place,
                               note: line.note, isPending: line.isPending)
        }
    }

    // MARK: October 2026, up to the 20th

    private static let october: [Line] = [
        Line(month: 0, day: 20, hour: 8, merchant: "Le Petit Fournil", category: .groceries, amount: -8.40,
             place: "Rue des Tanneurs", isPending: true),
        Line(month: 0, day: 20, hour: 17, merchant: "Swift Cabs", category: .transport, amount: -14.20,
             account: "credit", note: "Station to home", isPending: true),
        Line(month: 0, day: 20, hour: 6, merchant: "Cloud Locker", category: .subscriptions, amount: -2.99,
             account: "credit"),
        Line(month: 0, day: 19, hour: 9, merchant: "Bean & Leaf Café", category: .dining, amount: -6.80,
             account: "credit", place: "Quai Saint-Antoine"),
        Line(month: 0, day: 19, hour: 18, merchant: "Corner Greens", category: .groceries, amount: -21.30,
             place: "Place du Marché"),
        Line(month: 0, day: 18, hour: 15, merchant: "Vinyl Corner", category: .entertainment, amount: -29.99,
             account: "credit", note: "Two records for Sam's birthday"),
        Line(month: 0, day: 18, hour: 11, merchant: "Westline Rail", category: .travel, amount: -46.00,
             account: "credit", note: "Lyon on 7 November, return"),
        Line(month: 0, day: 17, hour: 20, merchant: "Sushi Komachi", category: .dining, amount: -38.50,
             account: "credit", place: "Rue Mercière"),
        Line(month: 0, day: 17, hour: 12, merchant: "Paper & Ink", category: .shopping, amount: 8.50,
             account: "credit", note: "Refund: returned notebook"),
        Line(month: 0, day: 16, hour: 18, merchant: "Harbor Market", category: .groceries, amount: -81.65,
             place: "Avenue du Port"),
        Line(month: 0, day: 15, hour: 10, merchant: "Fold Outfitters", category: .shopping, amount: -89.00,
             account: "credit", note: "Rain jacket"),
        Line(month: 0, day: 15, hour: 7, merchant: "Fibrelink Internet", category: .utilities, amount: -29.99),
        Line(month: 0, day: 14, hour: 13, merchant: "Blue Fern Pharmacy", category: .health, amount: -12.80,
             place: "Rue Victor Hugo"),
        Line(month: 0, day: 14, hour: 6, merchant: "Tune Box Music", category: .subscriptions, amount: -10.99,
             account: "credit"),
        Line(month: 0, day: 13, hour: 23, merchant: "Swift Cabs", category: .transport, amount: -18.40,
             account: "credit"),
        Line(month: 0, day: 12, hour: 9, merchant: "Transfer to Savings", category: .transfer, amount: -300.00,
             note: "Holiday fund"),
        Line(month: 0, day: 11, hour: 19, merchant: "Noodle Bar 88", category: .dining, amount: -16.90,
             account: "credit"),
        Line(month: 0, day: 11, hour: 10, merchant: "Corner Greens", category: .groceries, amount: -18.40,
             place: "Place du Marché"),
        Line(month: 0, day: 10, hour: 21, merchant: "Lumen Cinema", category: .entertainment, amount: -24.00,
             account: "credit", note: "Two tickets"),
        Line(month: 0, day: 9, hour: 18, merchant: "Harbor Market", category: .groceries, amount: -74.10,
             place: "Avenue du Port"),
        Line(month: 0, day: 9, hour: 7, merchant: "Signal Mobile", category: .utilities, amount: -24.99),
        Line(month: 0, day: 8, hour: 11, merchant: "Harbor Print Co.", category: .income, amount: 620.00,
             note: "Invoice 2026-031, poster series"),
        Line(month: 0, day: 7, hour: 9, merchant: "Bean & Leaf Café", category: .dining, amount: -5.20,
             account: "credit", place: "Quai Saint-Antoine"),
        Line(month: 0, day: 6, hour: 7, merchant: "Northwind Energy", category: .utilities, amount: -84.20),
        Line(month: 0, day: 5, hour: 18, merchant: "Atlas Gym", category: .health, amount: -39.00),
        Line(month: 0, day: 5, hour: 16, merchant: "Paper & Ink", category: .shopping, amount: -23.50,
             account: "credit"),
        Line(month: 0, day: 4, hour: 8, merchant: "Le Petit Fournil", category: .groceries, amount: -7.80,
             place: "Rue des Tanneurs"),
        Line(month: 0, day: 3, hour: 20, merchant: "Trattoria Sole", category: .dining, amount: -52.00,
             account: "credit", note: "Dinner with Inès and Tom"),
        Line(month: 0, day: 3, hour: 8, merchant: "City Transit", category: .transport, amount: -84.10,
             note: "Monthly pass"),
        Line(month: 0, day: 2, hour: 17, merchant: "Harbor Market", category: .groceries, amount: -68.35,
             place: "Avenue du Port"),
        Line(month: 0, day: 2, hour: 6, merchant: "Streamline Video", category: .subscriptions, amount: -12.99,
             account: "credit"),
        Line(month: 0, day: 1, hour: 9, merchant: "Bean & Leaf Café", category: .dining, amount: -4.60,
             account: "credit", place: "Quai Saint-Antoine"),
        Line(month: 0, day: 1, hour: 7, merchant: "Oak Street Lettings", category: .housing, amount: -1_150.00,
             note: "Rent, October"),
    ]

    // MARK: May to September 2026

    /// The same regular payments and habits every month, with amounts that vary a little.
    private static let earlierMonths: [Line] = (-5 ... -1).flatMap { month -> [Line] in
        let turn = month + 5   // 0 for May ... 4 for September
        let groceries: [Money] = [64.20, 71.85, 58.40, 77.10, 69.95]
        let coffee: [Money] = [4.60, 5.20, 4.60, 6.80, 5.20]
        let energy: [Money] = [61.40, 55.80, 52.10, 58.90, 72.30]
        var lines = [
            Line(month: month, day: 1, hour: 7, merchant: "Oak Street Lettings", category: .housing,
                 amount: -1_150.00),
            Line(month: month, day: 2, hour: 6, merchant: "Streamline Video", category: .subscriptions,
                 amount: -12.99, account: "credit"),
            Line(month: month, day: 3, hour: 8, merchant: "City Transit", category: .transport,
                 amount: -84.10, note: "Monthly pass"),
            Line(month: month, day: 5, hour: 18, merchant: "Atlas Gym", category: .health, amount: -39.00),
            Line(month: month, day: 6, hour: 7, merchant: "Northwind Energy", category: .utilities,
                 amount: -energy[turn]),
            Line(month: month, day: 9, hour: 7, merchant: "Signal Mobile", category: .utilities, amount: -24.99),
            Line(month: month, day: 14, hour: 6, merchant: "Tune Box Music", category: .subscriptions,
                 amount: -10.99, account: "credit"),
            Line(month: month, day: 15, hour: 7, merchant: "Fibrelink Internet", category: .utilities,
                 amount: -29.99),
            Line(month: month, day: 17, hour: 20, merchant: "Sushi Komachi", category: .dining,
                 amount: -(36.00 + Money(cents: turn * 125)), account: "credit"),
            Line(month: month, day: 20, hour: 6, merchant: "Cloud Locker", category: .subscriptions,
                 amount: -2.99, account: "credit"),
            Line(month: month, day: 25, hour: 9, merchant: "Northwind Studio", category: .income,
                 amount: 3_450.00, note: "Salary"),
        ]
        for (index, day) in [2, 9, 16, 23].enumerated() {
            lines.append(Line(month: month, day: day, hour: 18, merchant: "Harbor Market", category: .groceries,
                              amount: -groceries[(turn + index) % groceries.count], place: "Avenue du Port"))
        }
        for (index, day) in [1, 7, 12, 19, 26].enumerated() {
            lines.append(Line(month: month, day: day, hour: 9, merchant: "Bean & Leaf Café", category: .dining,
                              amount: -coffee[(turn + index) % coffee.count], account: "credit",
                              place: "Quai Saint-Antoine"))
        }
        if month == -1 {
            lines += [
                Line(month: month, day: 11, hour: 7, merchant: "Westline Rail", category: .travel, amount: -58.00,
                     account: "credit", note: "Coast weekend"),
                Line(month: month, day: 12, hour: 15, merchant: "Seaside Stays", category: .travel,
                     amount: -212.00, account: "credit", note: "Two nights"),
            ]
        }
        return lines
    }
}
