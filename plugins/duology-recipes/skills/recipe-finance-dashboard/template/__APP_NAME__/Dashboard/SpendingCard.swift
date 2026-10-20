import Charts
import SwiftUI

/// Everyday spending this month against an even pace to the budget.
///
/// The chart lives in one pane, so it never crosses the fold. It takes the pane's width and a
/// height that grows with Dynamic Type, never a size picked for one display.
struct SpendingCard: View {
    let pace: BudgetPace
    let daily: [DailySpend]
    let code: String
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 170

    var body: some View {
        DuoCard {
            VStack(alignment: .leading, spacing: DuoSpace.x3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Everyday spending")
                        .font(DuoType.itemTitle)
                    Spacer(minLength: DuoSpace.x2)
                    Text(pace.monthStart, format: .dateTime.month(.wide))
                        .font(DuoType.meta)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: DuoSpace.x1) {
                    HStack(alignment: .firstTextBaseline, spacing: DuoSpace.x2) {
                        Text(pace.spent.text(code))
                            .font(.title.weight(.bold))
                            .monospacedDigit()
                        Text("of \(pace.budget.roundedText(code))")
                            .font(DuoType.secondary)
                            .foregroundStyle(.secondary)
                    }
                    PaceLine(pace: pace, code: code)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("spending.total")

                chart
                    .frame(height: chartHeight)
                    .accessibilityIdentifier("spending.chart")

                HStack(spacing: DuoSpace.x4) {
                    LegendKey(title: "Spent", dash: [])
                    LegendKey(title: "Even pace", dash: [4, 4])
                }
                .font(DuoType.meta)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("spending.card")
    }

    private var chart: some View {
        let top = max(pace.budget, pace.spent).doubleValue * 1.08
        return Chart {
            ForEach(daily) { point in
                AreaMark(x: .value("Day", point.day), y: .value("Spent", point.cumulative.doubleValue))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.accentColor.opacity(0.32), Color.accentColor.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Day", point.day), y: .value("Spent", point.cumulative.doubleValue),
                         series: .value("Line", "Spent"))
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            // An even pace: nothing on day 0, the whole budget on the last day.
            ForEach([0, pace.daysInMonth], id: \.self) { day in
                LineMark(x: .value("Day", day), y: .value("Spent", pace.pace(atDay: day).doubleValue),
                         series: .value("Line", "Even pace"))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
            if let today = daily.last {
                PointMark(x: .value("Day", today.day), y: .value("Spent", today.cumulative.doubleValue))
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(60)
            }
        }
        .chartXScale(domain: 0...pace.daysInMonth)
        .chartYScale(domain: 0...top)
        .chartXAxis {
            AxisMarks(values: [1, 8, 15, 22, 29]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let day = value.as(Int.self) {
                        Text(dayLabel(day))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(Decimal(amount), format: .currency(code: code).precision(.fractionLength(0)))
                    }
                }
            }
        }
        .chartLegend(.hidden)
    }

    /// "1 Oct" style labels in the person's locale.
    private func dayLabel(_ day: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: day - 1, to: pace.monthStart) ?? pace.monthStart
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

/// "€126.74 under an even pace", or over it.
private struct PaceLine: View {
    let pace: BudgetPace
    let code: String

    var body: some View {
        let over = pace.isOverPace
        Label {
            Text(over
                 ? "\(pace.margin.magnitude.text(code)) over an even pace"
                 : "\(pace.margin.text(code)) under an even pace")
        } icon: {
            Image(systemName: over ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(over ? Color.orange : FinanceColor.income)
        }
        .font(DuoType.secondary)
        .foregroundStyle(.secondary)
    }
}

private struct LegendKey: View {
    let title: String
    let dash: [CGFloat]

    var body: some View {
        HStack(spacing: DuoSpace.x1) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 4))
                path.addLine(to: CGPoint(x: 18, y: 4))
            }
            .stroke(dash.isEmpty ? Color.accentColor : Color.secondary,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: dash))
            .frame(width: 18, height: 8)
            Text(title)
        }
    }
}

/// Spending per category this month. Tiles span 2 of the pane's 4 columns, so two sit
/// side by side; at accessibility text sizes the span doubles and they stack.
struct CategoryGrid: View {
    let totals: [CategoryTotal]
    let code: String
    @DuoMetrics private var tokens

    var body: some View {
        let perRow = max(1, tokens.columns / tokens.span(2))
        VStack(alignment: .leading, spacing: DuoSpace.x3) {
            Text("By category")
                .font(DuoType.sectionTitle)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: tokens.gutter, alignment: .top),
                                     count: perRow),
                      spacing: tokens.gutter) {
                ForEach(totals) { item in
                    CategoryTile(item: item, code: code)
                }
            }
        }
    }
}

private struct CategoryTile: View {
    let item: CategoryTotal
    let code: String

    var body: some View {
        DuoCard {
            VStack(alignment: .leading, spacing: DuoSpace.x2) {
                HStack(alignment: .top) {
                    CategoryIcon(category: item.category)
                    Spacer(minLength: DuoSpace.x1)
                    Text(item.share, format: .percent.precision(.fractionLength(0)))
                        .font(DuoType.meta.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.category.name)
                        .font(DuoType.secondary)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(item.total.text(code))
                        .font(.headline)
                        .monospacedDigit()
                }
                ShareBar(share: item.share, tint: item.category.tint)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("category.\(item.category.rawValue)")
    }
}

private struct ShareBar: View {
    let share: Double
    let tint: Color

    var body: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.18))
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(tint)
                        .frame(width: max(6, proxy.size.width * share))
                }
            }
            .accessibilityHidden(true)
    }
}
