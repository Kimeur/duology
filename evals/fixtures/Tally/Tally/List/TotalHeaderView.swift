import UIKit

/// The total at the top of the list, with the number of expenses under it.
final class TotalHeaderView: UIView {
    private let caption = UILabel()
    private let totalLabel = UILabel()
    private let countLabel = UILabel()
    private let amounts = UIStackView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        caption.text = "Total"
        caption.font = .preferredFont(forTextStyle: .subheadline)
        caption.textColor = .secondaryLabel

        totalLabel.font = .monospacedDigitSystemFont(ofSize: 40, weight: .bold)
        totalLabel.adjustsFontSizeToFitWidth = true
        totalLabel.minimumScaleFactor = 0.5

        countLabel.font = .preferredFont(forTextStyle: .footnote)
        countLabel.textColor = .secondaryLabel

        amounts.axis = .vertical
        amounts.spacing = 2
        amounts.addArrangedSubview(caption)
        amounts.addArrangedSubview(totalLabel)

        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.addArrangedSubview(amounts)
        stack.addArrangedSubview(countLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(total: Decimal, count: Int) {
        totalLabel.text = Expense.formatted(total)
        countLabel.text = count == 1 ? "1 expense" : "\(count) expenses"
    }

    /// Landscape puts the count beside the total.
    func useWideLayout(_ wide: Bool) {
        stack.axis = wide ? .horizontal : .vertical
        stack.alignment = wide ? .lastBaseline : .leading
        stack.spacing = wide ? 16 : 8
    }
}
