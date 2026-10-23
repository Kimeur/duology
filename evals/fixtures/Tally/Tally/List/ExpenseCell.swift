import UIKit

final class ExpenseCell: UITableViewCell {
    static let reuseIdentifier = "ExpenseCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ expense: Expense) {
        var content = UIListContentConfiguration.valueCell()
        content.text = expense.title
        content.secondaryText = Expense.formatted(expense.amount)
        content.image = UIImage(systemName: expense.category.symbolName)
        content.imageProperties.tintColor = .tintColor

        // Icons scale with the phone so they line up on every model.
        let side = (UIScreen.main.bounds.width / 14).rounded()
        content.imageProperties.reservedLayoutSize = CGSize(width: side, height: side)
        content.imageProperties.maximumSize = CGSize(width: side, height: side)
        contentConfiguration = content
    }
}
