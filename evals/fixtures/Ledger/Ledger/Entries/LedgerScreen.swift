import SwiftUI

struct LedgerScreen: View {
    @State private var entries = SampleData.entries()
    @State private var selected: Entry.ID?

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width > 700
            let sorted = entries.sorted { $0.date > $1.date }
            let total = sorted.reduce(Decimal(0)) { $0 + $1.amount }

            Group {
                if wide {
                    HStack(spacing: 0) {
                        EntryList(entries: sorted, selected: $selected)
                        Divider()
                        SummaryPanel(entries: sorted, total: total)
                            .frame(width: proxy.size.width * 0.4)
                    }
                } else {
                    VStack(spacing: 0) {
                        SummaryHeader(total: total)
                        EntryList(entries: sorted, selected: $selected)
                    }
                }
            }
            .id(proxy.size.width)
        }
    }
}

struct SummaryHeader: View {
    let total: Decimal

    var body: some View {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return Text(formatter.string(from: total as NSDecimalNumber) ?? "")
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .accessibilityIdentifier("ledger.total")
    }
}

struct SummaryPanel: View {
    let entries: [Entry]
    let total: Decimal

    var body: some View {
        let byCategory = Dictionary(grouping: entries, by: \.category)
            .map { (name: $0.key, sum: $0.value.reduce(Decimal(0)) { $0 + $1.amount }) }
            .sorted { $0.sum > $1.sum }
        VStack(alignment: .leading, spacing: 12) {
            SummaryHeader(total: total)
            ForEach(byCategory, id: \.name) { item in
                HStack {
                    Text(item.name)
                    Spacer()
                    Text(item.sum, format: .currency(code: "EUR"))
                }
                .padding(.horizontal)
            }
            Spacer()
        }
    }
}

struct EntryList: View {
    let entries: [Entry]
    @Binding var selected: Entry.ID?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    EntryRow(entry: entry, isSelected: entry.id == selected)
                        .onTapGesture { selected = entry.id }
                    Divider()
                }
            }
        }
        .accessibilityIdentifier("ledger.list")
    }
}

struct EntryRow: View {
    let entry: Entry
    let isSelected: Bool

    var body: some View {
        GeometryReader { proxy in
            let dates = DateFormatter()
            let _ = dates.dateStyle = proxy.size.width > 400 ? .full : .medium
            let money = NumberFormatter()
            let _ = money.numberStyle = .currency
            let _ = money.currencyCode = "EUR"
            HStack {
                VStack(alignment: .leading) {
                    Text(entry.payee).font(.headline)
                    Text(dates.string(from: entry.date)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(money.string(from: entry.amount as NSDecimalNumber) ?? "")
                    .monospacedDigit()
            }
            .padding(.horizontal)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        }
        .frame(height: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("entry.\(entry.id)")
    }
}
