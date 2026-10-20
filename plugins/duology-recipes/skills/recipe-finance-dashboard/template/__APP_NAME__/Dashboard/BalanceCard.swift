import SwiftUI

/// Total balance, each account, and money in and out this month.
struct BalanceCard: View {
    let ledger: Ledger
    let summary: MonthSummary
    @DuoMetrics private var tokens

    var body: some View {
        let code = ledger.currencyCode
        VStack(alignment: .leading, spacing: tokens.gutter) {
            VStack(alignment: .leading, spacing: DuoSpace.x4) {
                VStack(alignment: .leading, spacing: DuoSpace.x1) {
                    Text("Total balance")
                        .font(DuoType.secondary.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(ledger.balance.text(code))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .accessibilityLabel("Total balance, \(ledger.balance.text(code))")
                        .accessibilityIdentifier("balance.total")
                }
                VStack(spacing: DuoSpace.x2) {
                    ForEach(ledger.accounts) { account in
                        HStack(alignment: .firstTextBaseline) {
                            Text(account.name)
                            Spacer(minLength: DuoSpace.x2)
                            Text(account.balance.text(code)).monospacedDigit()
                        }
                        .font(DuoType.secondary)
                        .foregroundStyle(.white)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(tokens.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [FinanceColor.heroTop, FinanceColor.heroBottom],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: tokens.cardRadius)
            )

            // Two tiles, each half the pane's grid (span 2 of 4). At accessibility text
            // sizes the span doubles and they stack.
            let perRow = max(1, tokens.columns / tokens.span(2))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: tokens.gutter, alignment: .top),
                                     count: perRow),
                      spacing: tokens.gutter) {
                FlowTile(title: "Money in", amount: summary.moneyIn.signedText(code),
                         detail: "This month", symbol: "arrow.down.left", tint: FinanceColor.income)
                    .accessibilityIdentifier("summary.in")
                FlowTile(title: "Money out", amount: (-summary.moneyOut).text(code),
                         detail: "\(summary.bills.roundedText(code)) in bills",
                         symbol: "arrow.up.right", tint: .primary)
                    .accessibilityIdentifier("summary.out")
            }
        }
    }
}

private struct FlowTile: View {
    let title: String
    let amount: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        DuoCard {
            VStack(alignment: .leading, spacing: DuoSpace.x1) {
                Label(title, systemImage: symbol)
                    .font(DuoType.secondary.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(amount)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(detail)
                    .font(DuoType.meta)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
