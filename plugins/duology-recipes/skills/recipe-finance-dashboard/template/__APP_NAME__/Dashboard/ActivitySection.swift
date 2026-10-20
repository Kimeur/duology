import SwiftUI

/// Transactions grouped by day. Picking one sets the model's selection: open, it shows in the
/// trailing pane and the row stays highlighted; closed, the stack pushes it.
struct ActivitySection: View {
    @Bindable var model: FinanceModel
    /// Show only the newest few, with a button for the rest. Nil shows everything.
    var limit: Int?
    @State private var showsAll = false
    @DuoMetrics private var tokens

    var body: some View {
        let all = model.sections
        let total = all.reduce(0) { $0 + $1.transactions.count }
        let shown = showsAll ? all : Self.trim(all, to: limit)
        VStack(alignment: .leading, spacing: DuoSpace.x3) {
            HStack(alignment: .firstTextBaseline) {
                Text("Activity")
                    .font(DuoType.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: DuoSpace.x2)
                if let filter = model.filter {
                    Button {
                        model.filter = nil
                    } label: {
                        Label(filter.name, systemImage: "xmark.circle.fill")
                            .font(DuoType.secondary.weight(.medium))
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, DuoSpace.x3)
                            .duoTouchTarget()
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .accessibilityLabel("Clear filter: \(filter.name)")
                    .accessibilityIdentifier("filter.clear")
                }
            }

            if all.isEmpty {
                ContentUnavailableView("No Transactions", systemImage: "tray",
                                       description: Text("Nothing in this category yet."))
            }

            LazyVStack(alignment: .leading, spacing: tokens.gutter) {
                ForEach(shown) { section in
                    VStack(alignment: .leading, spacing: DuoSpace.x2) {
                        Text(title(for: section))
                            .font(DuoType.meta.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                        VStack(spacing: 0) {
                            ForEach(Array(section.transactions.enumerated()), id: \.element.id) { index, item in
                                if index > 0 {
                                    Divider().padding(.leading, 60)
                                }
                                TransactionRow(model: model, transaction: item)
                            }
                        }
                        .background(DuoColor.card, in: RoundedRectangle(cornerRadius: tokens.cardRadius))
                        .clipShape(RoundedRectangle(cornerRadius: tokens.cardRadius))
                    }
                }
            }
            .accessibilityIdentifier("activity.list")

            if !showsAll, let limit, total > limit {
                Button {
                    showsAll = true
                } label: {
                    Text("Show all \(total) transactions")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .duoTouchTarget()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("activity.showAll")
            }
        }
    }

    private func title(for section: DaySection) -> String {
        switch section.label {
        case .today: "Today"
        case .yesterday: "Yesterday"
        case .date(let day): day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        }
    }

    /// The newest `limit` transactions, still grouped by day.
    static func trim(_ sections: [DaySection], to limit: Int?) -> [DaySection] {
        guard var left = limit else { return sections }
        var result: [DaySection] = []
        for section in sections where left > 0 {
            var part = section
            part.transactions = Array(section.transactions.prefix(left))
            left -= part.transactions.count
            result.append(part)
        }
        return result
    }
}

private struct TransactionRow: View {
    @Bindable var model: FinanceModel
    let transaction: LedgerEntry
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let code = model.currencyCode
        let isSelected = model.isTwoPane && model.selection == transaction.id
        let account = model.account(for: transaction)?.name ?? ""
        Button {
            model.selection = transaction.id
        } label: {
            // At accessibility sizes the amount moves under the name instead of squeezing it.
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DuoSpace.x1))
                : AnyLayout(HStackLayout(alignment: .center, spacing: DuoSpace.x3))
            layout {
                HStack(spacing: DuoSpace.x3) {
                    CategoryIcon(category: transaction.category)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(transaction.merchant)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        HStack(spacing: DuoSpace.x1) {
                            Text("\(transaction.category.name) · \(account)")
                                .lineLimit(1)
                            if transaction.isPending {
                                Text("Pending")
                                    .font(DuoType.caption.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15), in: Capsule())
                            }
                        }
                        .font(DuoType.secondary)
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: DuoSpace.x2)
                Text(transaction.amount.isNegative ? transaction.amount.text(code) : transaction.amount.signedText(code))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(transaction.amount.isNegative ? Color.primary : FinanceColor.income)
            }
            .padding(.horizontal, DuoSpace.x3)
            .padding(.vertical, DuoSpace.x3)
            .frame(maxWidth: .infinity, minHeight: DuoTokens.minTouchTarget, alignment: .leading)
            .contentShape(.rect)
            .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(account: account))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("txn.\(transaction.id)")
    }

    private func accessibilityText(account: String) -> String {
        let code = model.currencyCode
        let amount = transaction.amount.isNegative
            ? "\(transaction.amount.magnitude.text(code)) out"
            : "\(transaction.amount.text(code)) in"
        let pending = transaction.isPending ? ", pending" : ""
        return "\(transaction.merchant), \(transaction.category.name), \(amount), \(account)\(pending)"
    }
}
