import SwiftUI

/// The dashboard.
///
/// Closed (compact width): one column. Balance, money in and out, the spending chart,
/// recent activity, then categories. A transaction pushes onto the stack.
///
/// Open (regular width): an even grid of 8 columns with the fold as its middle gutter.
/// Columns 1 to 4 hold the leading pane: balance, money in and out, and the whole
/// activity list. Columns 5 to 8 hold the trailing pane: the chart and categories, or the
/// transaction picked in the list. Each pane scrolls on its own, and the panes sit in the
/// same place flat and partly folded: only the gap at the fold grows.
struct DashboardScreen: View {
    @Bindable var model: FinanceModel
    @DuoMetrics private var tokens
    @State private var geometry = PaneGeometry()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Two panes only when the window is regular width. The frames come from the
        // dashboard's own width and fold, never from the screen.
        let frames = model.isTwoPane
            ? PaneFrames(width: geometry.width, count: tokens.columns, gutter: tokens.gutter, fold: geometry.fold)
            : nil
        FoldPanes(frames: frames) {
            ScrollView {
                OverviewColumn(model: model, isTwoPane: frames != nil)
            }
            .accessibilityIdentifier("pane.leading")
        } trailing: {
            ScrollView {
                if let transaction = model.selectedTransaction {
                    TransactionDetail(model: model, transaction: transaction) {
                        model.selection = nil
                    }
                    // A new transaction starts at the top, with VoiceOver on its name.
                    .id(transaction.id)
                } else {
                    SpendingColumn(model: model)
                }
            }
            .accessibilityIdentifier("pane.trailing")
        }
        // Measured inside the margins, so the fold comes back in the panes' coordinates.
        .onPaneGeometryChange { geometry = $0 }
        .duoContainerMargins()
        .background(DuoColor.groupedBackground)
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: model.selection)
        .navigationTitle("Overview")
        .toolbar {
            // A list action, so it stays with the dashboard. On iPhone Duo the system puts it
            // in the vertical bar on the side.
            ToolbarItem(placement: .primaryAction) {
                FilterMenu(filter: $model.filter)
            }
        }
    }
}

/// The leading pane when open, and the whole screen when closed.
private struct OverviewColumn: View {
    @Bindable var model: FinanceModel
    let isTwoPane: Bool
    @DuoMetrics private var tokens

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.sectionSpacing) {
            BalanceCard(ledger: model.ledger, summary: model.summary)
            if !isTwoPane {
                SpendingCard(pace: model.pace, daily: model.daily, code: model.currencyCode)
            }
            // Closed, the newest few, then a button for the rest. Open, the pane is the list.
            ActivitySection(model: model, limit: isTwoPane ? nil : 6)
            if !isTwoPane {
                CategoryGrid(totals: model.categories, code: model.currencyCode)
            }
        }
        .padding(.vertical, DuoSpace.x4)
    }
}

/// The trailing pane when open and nothing is picked.
private struct SpendingColumn: View {
    let model: FinanceModel
    @DuoMetrics private var tokens

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.sectionSpacing) {
            SpendingCard(pace: model.pace, daily: model.daily, code: model.currencyCode)
            CategoryGrid(totals: model.categories, code: model.currencyCode)
        }
        .padding(.vertical, DuoSpace.x4)
    }
}

private struct FilterMenu: View {
    @Binding var filter: Category?

    var body: some View {
        Menu {
            Picker("Show", selection: $filter) {
                Label("All activity", systemImage: "list.bullet").tag(Category?.none)
                ForEach(Category.allCases) { category in
                    Label(category.name, systemImage: category.symbol).tag(Category?.some(category))
                }
            }
        } label: {
            Label("Filter", systemImage: filter == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityIdentifier("filter.menu")
    }
}

/// Opened from the activity list on the closed phone.
struct TransactionScreen: View {
    let model: FinanceModel
    let id: LedgerEntry.ID

    var body: some View {
        ScrollView {
            if let transaction = model.ledger.transaction(id) {
                TransactionDetail(model: model, transaction: transaction, onClose: nil)
                    .duoContainerMargins()
            }
        }
        .background(DuoColor.groupedBackground)
        // The merchant is the heading right below, so the bar says what kind of screen it is.
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
    }
}
