import Charts
import SwiftUI

/// One transaction. Open, it fills the trailing pane, next to the list it came from; closed,
/// the stack pushes it. The same view in both, so a category changed here stays changed
/// when the phone opens or closes.
struct TransactionDetail: View {
    @Bindable var model: FinanceModel
    let transaction: LedgerEntry
    /// Two panes: closes the detail and brings the chart back. Nil when the stack pushed it,
    /// because the back button does that job.
    var onClose: (() -> Void)?
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DuoSpace.x6) {
            header
            facts
            MerchantHistory(transaction: transaction, months: model.history(for: transaction),
                            code: model.currencyCode)
        }
        .padding(.vertical, DuoSpace.x4)
        .onAppear {
            // Open, the detail appears beside the list. Move VoiceOver to it, or it would
            // stay on the row in the other pane and say nothing changed.
            if onClose != nil { titleFocused = true }
        }
    }

    private var header: some View {
        let code = model.currencyCode
        return VStack(alignment: .leading, spacing: DuoSpace.x3) {
            HStack(alignment: .top) {
                CategoryIcon(category: transaction.category)
                    .scaleEffect(1.3, anchor: .topLeading)
                    .padding(.bottom, DuoSpace.x3)
                Spacer()
                if let onClose {
                    // Glass on a control, never on content. Top trailing: outside the fold
                    // when the phone is partly folded, as the whole pane is.
                    Button(action: onClose) {
                        // The glass circle adds its own padding: a 32 pt label gives a hit
                        // region of at least 44 pt (the UI tests check the frame).
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 32, height: 32)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("detail.close")
                }
            }
            Text(transaction.merchant)
                .font(.title.weight(.bold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($titleFocused)
                .accessibilityIdentifier("detail.title")
            Text(transaction.amount.isNegative ? transaction.amount.text(code) : transaction.amount.signedText(code))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(transaction.amount.isNegative ? Color.primary : FinanceColor.income)
                .accessibilityIdentifier("detail.amount")
            HStack(spacing: DuoSpace.x2) {
                Text(transaction.date, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute())
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

    private var facts: some View {
        DuoCard {
            VStack(spacing: DuoSpace.x3) {
                // An HStack, not LabeledContent: LabeledContent merges the label and the
                // picker into one accessibility element as wide as the row, and a tap on
                // its centre misses the picker (measured in the UI tests).
                HStack {
                    Text("Category")
                    Spacer(minLength: DuoSpace.x2)
                    if transaction.category.isSpending {
                        Picker("Category", selection: Binding(
                            get: { transaction.category },
                            set: { model.setCategory($0, for: transaction.id) }
                        )) {
                            // Text only: the row shows the chosen name, and a long one
                            // ("Entertainment") stays on one line in a half-width pane.
                            ForEach(Category.spending) { category in
                                Text(category.name).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .fixedSize()
                        .accessibilityIdentifier("detail.category")
                    } else {
                        Text(transaction.category.name)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: DuoTokens.minTouchTarget)
                Divider()
                LabeledContent("Account", value: model.account(for: transaction)?.name ?? "Unknown")
                if let place = transaction.place {
                    Divider()
                    LabeledContent("Place", value: place)
                }
                if let note = transaction.note {
                    Divider()
                    LabeledContent("Note", value: note)
                }
                Divider()
                LabeledContent("Status", value: transaction.isPending ? "Pending" : "Settled")
            }
            .font(DuoType.body)
        }
    }
}

/// What this merchant cost in each of the last six months, with the average as a rule.
private struct MerchantHistory: View {
    let transaction: LedgerEntry
    let months: [MonthTotal]
    let code: String
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 120

    var body: some View {
        let total = months.map(\.total).sum()
        let activeMonths = months.filter { $0.total > .zero }.count
        if transaction.category.isSpending, total > .zero {
            let average = Money(cents: total.cents / max(months.count, 1))
            DuoCard {
                VStack(alignment: .leading, spacing: DuoSpace.x3) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("At \(transaction.merchant)")
                            .font(DuoType.itemTitle)
                        // An average only means something when the merchant comes back.
                        Text(activeMonths > 1
                             ? "\(total.text(code)) in six months, about \(average.text(code)) a month"
                             : "\(total.text(code)) in six months")
                            .font(DuoType.secondary)
                            .foregroundStyle(.secondary)
                    }
                    Chart {
                        ForEach(months) { month in
                            BarMark(x: .value("Month", month.monthStart, unit: .month),
                                    y: .value("Spent", month.total.doubleValue))
                                .foregroundStyle(month.id == months.last?.id
                                                 ? AnyShapeStyle(transaction.category.tint.gradient)
                                                 : AnyShapeStyle(Color.secondary.opacity(0.35)))
                                .cornerRadius(4)
                        }
                        if activeMonths > 1 {
                            RuleMark(y: .value("Average", average.doubleValue))
                                .foregroundStyle(Color.secondary)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                        }
                    }
                    .chartYAxis(.hidden)
                    .frame(height: chartHeight)
                    .accessibilityIdentifier("detail.history")
                }
            }
        }
    }
}
