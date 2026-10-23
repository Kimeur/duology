import UIKit

final class ExpenseListViewController: UITableViewController {
    private let store: ExpenseStore
    private let header = TotalHeaderView()

    init(store: ExpenseStore) {
        self.store = store
        super.init(style: .insetGrouped)
        title = "Tally"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.leftBarButtonItem = editButtonItem
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .add,
            primaryAction: UIAction { [weak self] _ in self?.showNewExpense() }
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "New Expense"

        tableView.register(ExpenseCell.self, forCellReuseIdentifier: ExpenseCell.reuseIdentifier)

        // The summary takes the top fifth of the screen.
        header.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width,
                              height: UIScreen.main.bounds.height * 0.2)
        tableView.tableHeaderView = header

        NotificationCenter.default.addObserver(
            self, selector: #selector(storeDidChange), name: ExpenseStore.didChange, object: store)
        updateHeader()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateHeader()
        })
    }

    @objc private func storeDidChange() {
        updateHeader()
    }

    private func updateHeader() {
        header.show(total: store.total, count: store.expenses.count)
        header.useWideLayout(UIDevice.current.orientation.isLandscape)
    }

    // MARK: - Adding

    private func showNewExpense() {
        let alert = UIAlertController(title: "New Expense", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "What was it?"
            field.autocapitalizationType = .sentences
        }
        alert.addTextField { field in
            field.placeholder = "Amount"
            field.keyboardType = .decimalPad
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self, weak alert] _ in
            let title = alert?.textFields?[0].text ?? ""
            let amount = alert?.textFields?[1].text ?? ""
            self?.addExpense(title: title, amount: amount)
        })
        present(alert, animated: true)
    }

    private func addExpense(title: String, amount: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let normalized = amount.replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty, let value = Decimal(string: normalized), value > 0 else { return }
        let cents = NSDecimalNumber(decimal: value * 100).intValue
        store.add(Expense(title: trimmed, cents: cents, category: .other, date: Date()))
        tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
    }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        store.expenses.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ExpenseCell.reuseIdentifier, for: indexPath) as! ExpenseCell
        cell.show(store.expenses[indexPath.row])
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let detail = ExpenseDetailViewController(expense: store.expenses[indexPath.row])
        navigationController?.pushViewController(detail, animated: true)
    }

    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete else { return }
        store.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
}
