import Foundation

/// Keeps the list of expenses and writes it to a JSON file in Documents.
final class ExpenseStore {
    static let shared = ExpenseStore()
    static let didChange = Notification.Name("ExpenseStoreDidChange")

    private(set) var expenses: [Expense] = []
    private let fileURL: URL

    init(fileURL: URL = ExpenseStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    var total: Decimal {
        expenses.reduce(Decimal(0)) { $0 + $1.amount }
    }

    func add(_ expense: Expense) {
        expenses.insert(expense, at: 0)
        changed()
    }

    func remove(at index: Int) {
        guard expenses.indices.contains(index) else { return }
        expenses.remove(at: index)
        changed()
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(expenses)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Could not save expenses: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([Expense].self, from: data) else {
            expenses = Expense.samples
            return
        }
        expenses = saved
    }

    private func changed() {
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    static var defaultFileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("expenses.json")
    }
}
