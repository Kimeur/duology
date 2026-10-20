import SwiftUI

extension Category {
    /// System colours, so they adapt to dark mode and Increase Contrast.
    var tint: Color {
        switch self {
        case .groceries: .green
        case .dining: .orange
        case .transport: .blue
        case .shopping: .pink
        case .health: .red
        case .entertainment: .purple
        case .travel: .cyan
        case .housing: .indigo
        case .utilities: .brown
        case .subscriptions: .teal
        case .income: .green
        case .transfer: .gray
        }
    }
}

/// A category's symbol on its colour. Decoration: rows and cards say the category in words.
struct CategoryIcon: View {
    let category: Category
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 36

    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(category.tint.gradient, in: RoundedRectangle(cornerRadius: size * 0.3))
            .accessibilityHidden(true)
    }
}

extension Money {
    /// "€1,286.40", or "-€8.40" for money out. In the person's locale.
    func text(_ code: String) -> String {
        decimal.formatted(.currency(code: code))
    }

    /// "+€620.00" for money in, "-€8.40" for money out.
    func signedText(_ code: String) -> String {
        decimal.formatted(.currency(code: code).sign(strategy: .always()))
    }

    /// "€1,286" for axis labels and headlines.
    func roundedText(_ code: String) -> String {
        decimal.formatted(.currency(code: code).precision(.fractionLength(0)))
    }
}

/// The app's own colours. Each has light, dark and contrast-checked values.
enum FinanceColor {
    /// Money in. Darker than system green so small text keeps 4.5:1 on white.
    static let income = DuoColor.dynamic(light: UIColor(red: 0.08, green: 0.50, blue: 0.24, alpha: 1),
                                         dark: UIColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1))
    /// The balance card. Deep in both modes, so white text on it stays above 5:1.
    static let heroTop = Color(red: 0.06, green: 0.46, blue: 0.43)
    static let heroBottom = Color(red: 0.04, green: 0.31, blue: 0.29)
}
