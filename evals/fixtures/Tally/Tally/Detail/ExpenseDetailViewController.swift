import UIKit

/// One expense: its category icon, the amount and the details under it.
final class ExpenseDetailViewController: UIViewController {
    private let expense: Expense
    private let iconView = UIImageView()
    private let content = UIStackView()
    private lazy var iconSize = iconView.widthAnchor.constraint(equalToConstant: 120)

    init(expense: Expense) {
        self.expense = expense
        super.init(nibName: nil, bundle: nil)
        title = expense.title
        navigationItem.largeTitleDisplayMode = .never
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        iconView.image = UIImage(systemName: expense.category.symbolName)
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .tintColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let fields = UIStackView(arrangedSubviews: [
            row("Amount", Expense.formatted(expense.amount), large: true),
            row("Category", expense.category.title),
            row("Date", expense.date.formatted(date: .long, time: .omitted)),
        ])
        fields.axis = .vertical
        fields.spacing = 16
        if !expense.note.isEmpty {
            fields.addArrangedSubview(row("Note", expense.note))
        }

        // iPad has room for the icon beside the details.
        let sideBySide = UIDevice.current.userInterfaceIdiom == .pad
        content.axis = sideBySide ? .horizontal : .vertical
        content.alignment = sideBySide ? .top : .center
        content.spacing = 24
        content.addArrangedSubview(iconView)
        content.addArrangedSubview(fields)
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)

        let guide = view.layoutMarginsGuide
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            content.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            iconSize,
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),
        ])
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // Smaller phones (iPhone SE and 8) get a smaller icon so the note stays visible.
        let side: CGFloat = view.bounds.height <= 667 ? 64 : 120
        if iconSize.constant != side {
            iconSize.constant = side
        }
    }

    private func row(_ name: String, _ value: String, large: Bool = false) -> UIView {
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .preferredFont(forTextStyle: .caption1)
        nameLabel.textColor = .secondaryLabel

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .preferredFont(forTextStyle: large ? .largeTitle : .body)
        valueLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [nameLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }
}
