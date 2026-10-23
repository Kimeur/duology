import Foundation

struct Expense: Codable, Equatable, Identifiable {
    enum Category: String, Codable, CaseIterable {
        case food
        case transport
        case home
        case fun
        case other

        var title: String {
            switch self {
            case .food: return "Food"
            case .transport: return "Transport"
            case .home: return "Home"
            case .fun: return "Fun"
            case .other: return "Other"
            }
        }

        var symbolName: String {
            switch self {
            case .food: return "cart.fill"
            case .transport: return "tram.fill"
            case .home: return "house.fill"
            case .fun: return "ticket.fill"
            case .other: return "tag.fill"
            }
        }
    }

    var id = UUID()
    var title: String
    /// Stored in cents so totals add up exactly.
    var cents: Int
    var category: Category
    var date: Date
    var note: String = ""

    var amount: Decimal {
        Decimal(cents) / 100
    }
}

extension Expense {
    static func formatted(_ amount: Decimal) -> String {
        let code = Locale.current.currency?.identifier ?? "EUR"
        return amount.formatted(.currency(code: code))
    }

    static var samples: [Expense] {
        let day: TimeInterval = 24 * 60 * 60
        let now = Date()
        return [
            Expense(title: "Groceries", cents: 6420, category: .food,
                    date: now.addingTimeInterval(-1 * day), note: "Weekly shop"),
            Expense(title: "Train pass", cents: 8900, category: .transport,
                    date: now.addingTimeInterval(-2 * day), note: "Monthly pass"),
            Expense(title: "Electricity", cents: 7235, category: .home,
                    date: now.addingTimeInterval(-4 * day), note: "September bill"),
            Expense(title: "Cinema", cents: 2400, category: .fun,
                    date: now.addingTimeInterval(-6 * day), note: "Two tickets"),
            Expense(title: "Coffee beans", cents: 1590, category: .food,
                    date: now.addingTimeInterval(-8 * day)),
            Expense(title: "Bike repair", cents: 3850, category: .transport,
                    date: now.addingTimeInterval(-11 * day), note: "New brake pads"),
        ]
    }
}
