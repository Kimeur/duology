import Foundation

struct Entry: Identifiable, Hashable {
    let id: Int
    let payee: String
    let category: String
    let amount: Decimal
    let date: Date
}

enum SampleData {
    static let payees = ["Corner Bakery", "City Transit", "Green Grocer", "Book Nook", "Cinema Royal",
                         "Hardware Hub", "Coffee Lab", "Pharmacy Plus", "Pet Palace", "Fresh Market"]
    static let categories = ["Food", "Transport", "Shopping", "Health", "Leisure"]

    /// 2,000 entries over the last year, the same every launch.
    static func entries() -> [Entry] {
        let start = Date(timeIntervalSince1970: 1_761_955_200) // 1 Nov 2025
        return (0..<2_000).map { i in
            Entry(id: i,
                  payee: payees[(i * 7) % payees.count],
                  category: categories[(i * 3) % categories.count],
                  amount: Decimal((i * 7_919) % 9_000 + 150) / 100,
                  date: start.addingTimeInterval(Double((i * 104_729) % 31_536_000)))
        }
    }
}
