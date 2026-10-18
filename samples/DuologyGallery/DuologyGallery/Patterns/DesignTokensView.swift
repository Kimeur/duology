import SwiftUI
import UIKit

/// Design tokens: a home energy dashboard laid out on the `duo-design-system`
/// tokens, with the layout grid drawn over it.
///
/// - Columns come from the size class: 4 on the outer display, 8 on the inner
///   display. Both counts are even, so a fold always lands in a gutter.
/// - Margins are the system's container margins (iOS 27.1). They can differ on
///   each side next to a vertical bar, and the overlay shows both.
/// - Partly folded, the fold's frame becomes the middle gutter: half the
///   columns on each side, outer margins unchanged (`DuoColumns`).
/// - One type scale on both displays, read live at the current text size.
/// - Every tappable element has a hit region of at least 44 × 44 pt. The touch
///   target overlay outlines each one, and the tokens card reports the smallest.
///
/// Skill: `duo-design-system` (`references/tokens.md`, `references/grid.md`).
struct DesignTokensView: View {
    @State private var showsGrid = true
    @State private var showsTargets = true

    var body: some View {
        NavigationStack {
            EnergyDashboard(showsGrid: showsGrid, showsTargets: showsTargets)
                .navigationTitle("Home Energy")
                .navigationBarTitleDisplayMode(.inline)
                .galleryCloseButton()
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Toggle(isOn: $showsGrid) {
                            Label("Layout Grid", systemImage: "rectangle.split.3x1")
                        }
                        Toggle(isOn: $showsTargets) {
                            Label("Touch Targets", systemImage: "hand.tap")
                        }
                    }
                }
                .toggleStyle(.button)
        }
    }
}

// MARK: - Dashboard

private struct EnergyDashboard: View {
    let showsGrid: Bool
    let showsTargets: Bool

    @DuoMetrics private var tokens
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grid = DuoGridGeometry()
    /// The grid's frame inside the full-width content, to draw the margins.
    @State private var gridFrame = CGRect.zero
    @State private var contentWidth: CGFloat = 0
    @State private var fold = FoldGeometry()
    @State private var smallestTarget: CGSize?
    @State private var devices = EnergyDevice.samples
    @State private var range = ChartRange.week

    nonisolated private static let space = "dashboard"

    var body: some View {
        let columns = DuoColumns(width: grid.width, count: tokens.columns, gutter: tokens.gutter, fold: grid.fold)
        ScrollView {
            VStack(alignment: .leading, spacing: tokens.sectionSpacing) {
                Legend(columns: columns, gutter: tokens.gutter, fold: grid.fold)

                section("Today") {
                    LazyVGrid(columns: columns.grouped(by: tokens.span(2)).gridItems,
                              alignment: .leading, spacing: tokens.gutter) {
                        ForEach(EnergyStat.today) { stat in
                            StatCard(stat: stat)
                        }
                    }
                }

                section("Last 7 days") {
                    LazyVGrid(columns: columns.grouped(by: tokens.span(4)).gridItems,
                              alignment: .leading, spacing: tokens.gutter) {
                        ChartCard(range: $range)
                        TariffCard()
                    }
                }

                section("Devices") {
                    LazyVGrid(columns: columns.grouped(by: tokens.span(2)).gridItems,
                              alignment: .leading, spacing: tokens.gutter) {
                        ForEach($devices) { $device in
                            DeviceCard(device: $device)
                        }
                    }
                }

                section("Tokens in use") {
                    LazyVGrid(columns: columns.grouped(by: tokens.span(4)).gridItems,
                              alignment: .leading, spacing: tokens.gutter) {
                        TokensCard(tokens: tokens, columns: columns, gridFold: grid.fold,
                                   margins: margins, smallestTarget: smallestTarget, typeSize: typeSize)
                        TypeScaleCard(typeSize: typeSize)
                    }
                }
            }
            // The grid reads its own width and the fold, before the margins.
            .readGridGeometry { grid = $0 }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { gridFrame = $0 }
            .containerMargins(.horizontal)
            .padding(.vertical, DuoSpace.x4)
            .overlay {
                if showsGrid {
                    GridOverlay(columns: columns, gridFrame: gridFrame)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
            .coordinateSpace(.named(Self.space))
        }
        // The fold stays put while the content scrolls, so it is drawn over the scroll view.
        .overlay {
            if showsGrid {
                FoldBand(fold: fold)
            }
        }
        .onFoldChange { fold = $0 }
        .onPreferenceChange(SmallestTargetKey.self) { size in
            smallestTarget = size
        }
        .environment(\.showsTouchTargets, showsTargets)
        .background(DuoColor.groupedBackground)
        // Columns glide when the fold changes the middle gutter. Nil under Reduce Motion.
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: grid)
    }

    private var margins: (leading: CGFloat, trailing: CGFloat) {
        (max(0, gridFrame.minX), max(0, contentWidth - gridFrame.maxX))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DuoSpace.x3) {
            Text(title)
                .font(DuoType.sectionTitle)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

private extension View {
    /// The grid geometry: width always, the fold from iOS 27.1.
    @ViewBuilder
    func readGridGeometry(_ action: @escaping (DuoGridGeometry) -> Void) -> some View {
        if #available(iOS 27.1, *) {
            onGeometryChange(for: DuoGridGeometry.self) { proxy in
                DuoGridGeometry(proxy)
            } action: { geometry in
                action(geometry)
            }
        } else {
            onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                var geometry = DuoGridGeometry()
                geometry.width = width
                action(geometry)
            }
        }
    }
}

/// What the overlay colours mean, and the grid in one line.
private struct Legend: View {
    let columns: DuoColumns
    let gutter: CGFloat
    let fold: DuoFold?

    private var summary: String {
        let count = columns.columns.count
        var text = "\(count) columns, \(Int(gutter)) pt gutters, system margins."
        if let fold {
            text += fold.isActive
                ? " Folded: \(count / 2) columns each side of a \(Int(fold.maxX - fold.minX)) pt fold gutter."
                : " Fold the phone and the middle gutter widens to the fold."
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DuoSpace.x3) {
            Text(summary)
                .font(DuoType.secondary)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DuoSpace.x2) { swatches }
                VStack(alignment: .leading, spacing: DuoSpace.x2) {
                    HStack(spacing: DuoSpace.x2) { firstSwatches }
                    HStack(spacing: DuoSpace.x2) { secondSwatches }
                }
            }
            .font(DuoType.meta.weight(.medium))
        }
    }

    @ViewBuilder private var swatches: some View { firstSwatches; secondSwatches }

    @ViewBuilder private var firstSwatches: some View {
        Swatch(title: "Columns", color: GridOverlay.columnColor)
        Swatch(title: "Margins", color: GridOverlay.marginColor)
    }

    @ViewBuilder private var secondSwatches: some View {
        Swatch(title: "Fold", color: FoldBand.color)
        Swatch(title: "Touch targets", color: TouchTargetMarker.color, dashed: true)
    }
}

private struct Swatch: View {
    let title: String
    let color: Color
    var dashed = false

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(dashed ? .clear : color.opacity(0.35))
                .strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: dashed ? [3, 2] : []))
                .frame(width: 14, height: 14)
            Text(title)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DuoColor.card, in: Capsule())
    }
}

// MARK: - Overlays

/// Columns and margins, drawn over the full-width content. The grid's own
/// frame tells it where the margins end.
private struct GridOverlay: View {
    let columns: DuoColumns
    let gridFrame: CGRect

    static let columnColor = Color(hex: 0xE5484D)
    static let marginColor = Color(hex: 0x3E63DD)

    var body: some View {
        Canvas { context, size in
            let leading = CGRect(x: 0, y: 0, width: max(0, gridFrame.minX), height: size.height)
            let trailing = CGRect(x: gridFrame.maxX, y: 0, width: max(0, size.width - gridFrame.maxX), height: size.height)
            for margin in [leading, trailing] where margin.width > 0 {
                context.fill(Path(margin), with: .color(Self.marginColor.opacity(0.12)))
            }
            for column in columns.columns {
                let rect = CGRect(x: gridFrame.minX + column.x, y: 0, width: column.width, height: size.height)
                context.fill(Path(rect), with: .color(Self.columnColor.opacity(0.05)))
                var edges = Path()
                edges.move(to: CGPoint(x: rect.minX + 0.5, y: 0))
                edges.addLine(to: CGPoint(x: rect.minX + 0.5, y: size.height))
                edges.move(to: CGPoint(x: rect.maxX - 0.5, y: 0))
                edges.addLine(to: CGPoint(x: rect.maxX - 0.5, y: size.height))
                context.stroke(edges, with: .color(Self.columnColor.opacity(0.35)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The fold, from the `.division` reserved region: filled while it is active,
/// dashed while the phone lies flat.
private struct FoldBand: View {
    let fold: FoldGeometry

    static let color = Color(hex: 0xD6409F)

    var body: some View {
        if let frame = fold.frame {
            let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
            ZStack(alignment: .top) {
                shape.fill(Self.color.opacity(fold.isActive ? 0.22 : 0.05))
                shape.strokeBorder(Self.color.opacity(0.8),
                                   style: StrokeStyle(lineWidth: 1.5, dash: fold.isActive ? [] : [5, 4]))
            }
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// Gives a control a 44 × 44 pt hit region and, while the overlay is on,
/// outlines that region: green when it is at least 44 pt each way, red when not.
private struct TouchTargetMarker: ViewModifier {
    @Environment(\.showsTouchTargets) private var isShown

    static let color = Color(hex: 0x18A058)

    func body(content: Content) -> some View {
        content
            .duoTouchTarget()
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: SmallestTargetKey.self, value: proxy.size)
                }
            }
            .overlay {
                if isShown {
                    GeometryReader { proxy in
                        let isLargeEnough = proxy.size.width >= DuoTokens.minTouchTarget
                            && proxy.size.height >= DuoTokens.minTouchTarget
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(isLargeEnough ? Self.color : .red,
                                          style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
    }
}

private extension View {
    func touchTarget() -> some View { modifier(TouchTargetMarker()) }
}

/// The smallest hit region on screen.
nonisolated private struct SmallestTargetKey: PreferenceKey {
    static let defaultValue: CGSize? = nil

    static func reduce(value: inout CGSize?, nextValue: () -> CGSize?) {
        guard let next = nextValue() else { return }
        guard let current = value else { value = next; return }
        value = min(next.width, next.height) < min(current.width, current.height) ? next : current
    }
}

extension EnvironmentValues {
    @Entry var showsTouchTargets = false
}

// MARK: - Cards

private struct StatCard: View {
    let stat: EnergyStat

    var body: some View {
        DuoCard {
            VStack(alignment: .leading, spacing: DuoSpace.x2) {
                Label(stat.title, systemImage: stat.symbol)
                    .font(DuoType.secondary.weight(.medium))
                    .foregroundStyle(stat.tint)
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: DuoSpace.x1) {
                    Text(stat.value)
                        .font(.title.weight(.bold))
                        .monospacedDigit()
                    Text(stat.unit)
                        .font(DuoType.secondary)
                        .foregroundStyle(.secondary)
                }
                // Two lines reserved, so cards in a row share one height.
                Text(stat.detail)
                    .font(DuoType.meta)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private enum ChartRange: String, CaseIterable, Identifiable {
    case week = "7 days"
    case month = "4 weeks"
    var id: String { rawValue }
}

private struct ChartCard: View {
    @Binding var range: ChartRange

    private var bars: [(String, Double)] {
        switch range {
        case .week:
            [("Mon", 9.8), ("Tue", 12.1), ("Wed", 6.4), ("Thu", 11.3), ("Fri", 13.0), ("Sat", 10.7), ("Sun", 12.6)]
        case .month:
            [("22 Sep", 74), ("29 Sep", 66), ("6 Oct", 58), ("13 Oct", 71)]
        }
    }

    var body: some View {
        DuoCard {
            VStack(alignment: .leading, spacing: DuoSpace.x3) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Solar generated")
                            .font(DuoType.itemTitle)
                        Text("\(bars.reduce(0) { $0 + $1.1 }, format: .number.precision(.fractionLength(1))) kWh")
                            .font(DuoType.secondary)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Spacer(minLength: DuoSpace.x2)
                }
                HStack(spacing: DuoSpace.x1) {
                    ForEach(ChartRange.allCases) { option in
                        Button(option.rawValue) { range = option }
                            .font(DuoType.meta.weight(.semibold))
                            .padding(.horizontal, DuoSpace.x3)
                            .touchTarget()
                            .background(range == option ? Color.orange.opacity(0.18) : Color(.tertiarySystemFill),
                                        in: Capsule())
                            .foregroundStyle(range == option ? Color.orange : Color.primary)
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(range == option ? .isSelected : [])
                    }
                }
                BarChart(bars: bars)
                    .frame(height: 120)
            }
        }
    }
}

private struct BarChart: View {
    let bars: [(String, Double)]

    var body: some View {
        let top = bars.map(\.1).max() ?? 1
        HStack(alignment: .bottom, spacing: DuoSpace.x2) {
            ForEach(bars.indices, id: \.self) { index in
                let isLast = index == bars.count - 1
                VStack(spacing: DuoSpace.x1) {
                    GeometryReader { proxy in
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isLast ? Color.orange : Color.orange.opacity(0.45))
                                .frame(height: proxy.size.height * bars[index].1 / top)
                        }
                    }
                    Text(bars[index].0)
                        .font(DuoType.caption)
                        .foregroundStyle(isLast ? .primary : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Solar generated")
        .accessibilityValue(bars.map { "\($0.0) \($0.1.formatted()) kilowatt hours" }.joined(separator: ", "))
    }
}

private struct TariffCard: View {
    private let bands: [(String, String, String, Color)] = [
        ("Off-peak", "00:30 to 05:30", "7.5p", .green),
        ("Standard", "05:30 to 16:00, 19:00 to 00:30", "24.9p", .blue),
        ("Peak", "16:00 to 19:00", "34.2p", .red)
    ]

    var body: some View {
        DuoCard {
            VStack(alignment: .leading, spacing: DuoSpace.x3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tariff")
                        .font(DuoType.itemTitle)
                    Text("Prices per kWh, export at 15p")
                        .font(DuoType.secondary)
                        .foregroundStyle(.secondary)
                }
                ForEach(bands, id: \.0) { band in
                    HStack(alignment: .firstTextBaseline, spacing: DuoSpace.x3) {
                        Circle()
                            .fill(band.3)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(band.0)
                                .font(DuoType.body.weight(.medium))
                            Text(band.1)
                                .font(DuoType.meta)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: DuoSpace.x2)
                        Text(band.2)
                            .font(DuoType.body.weight(.semibold))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct DeviceCard: View {
    @Binding var device: EnergyDevice

    var body: some View {
        DuoCard {
            VStack(alignment: .leading, spacing: DuoSpace.x2) {
                HStack(alignment: .top) {
                    Image(systemName: device.symbol)
                        .font(.title2)
                        .foregroundStyle(device.isOn ? device.tint : .secondary)
                        .frame(height: 44)
                        .accessibilityHidden(true)
                    Spacer(minLength: DuoSpace.x2)
                    Button(device.isOn ? "Turn Off \(device.name)" : "Turn On \(device.name)", systemImage: "power") {
                        device.isOn.toggle()
                    }
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(device.isOn ? .white : .secondary)
                    .touchTarget()
                    .background(device.isOn ? device.tint : Color(.tertiarySystemFill), in: Circle())
                    .buttonStyle(.plain)
                }
                Text(device.name)
                    .font(DuoType.itemTitle)
                    .lineLimit(1)
                Text(device.isOn ? device.onStatus : "Off")
                    .font(DuoType.meta)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            }
        }
    }
}

private struct TokensCard: View {
    let tokens: DuoTokens
    let columns: DuoColumns
    let gridFold: DuoFold?
    let margins: (leading: CGFloat, trailing: CGFloat)
    let smallestTarget: CGSize?
    let typeSize: DynamicTypeSize

    private var rows: [(String, String)] {
        var middle = "\(points(tokens.gutter)), no fold"
        if let gridFold {
            middle = gridFold.isActive
                ? "\(points(gridFold.maxX - gridFold.minX)), the fold"
                : "\(points(tokens.gutter)), fold flat"
        }
        let target = smallestTarget.map { "\(Int($0.width.rounded())) × \(Int($0.height.rounded())) pt" } ?? "None"
        return [
            ("Width class", tokens.isRegularWidth ? "Regular" : "Compact"),
            ("Columns", "\(columns.columns.count)"),
            ("Gutter", points(tokens.gutter)),
            ("Middle gutter", middle),
            ("Margins", "\(points(margins.leading)) leading, \(points(margins.trailing)) trailing"),
            ("Card padding", points(tokens.cardPadding)),
            ("Card corner", points(tokens.cardRadius)),
            ("Section spacing", points(tokens.sectionSpacing)),
            ("Smallest target", target),
            ("Text size", TypeScaleCard.name(of: typeSize))
        ]
    }

    var body: some View {
        DuoCard {
            VStack(alignment: .leading, spacing: DuoSpace.x2) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This view")
                        .font(DuoType.itemTitle)
                    Text("Read live from the size class and the grid's own width")
                        .font(DuoType.secondary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, DuoSpace.x1)
                ForEach(rows, id: \.0) { row in
                    HStack(alignment: .firstTextBaseline, spacing: DuoSpace.x3) {
                        Text(row.0)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: DuoSpace.x2)
                        Text(row.1)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                    }
                    .font(DuoType.meta)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func points(_ value: CGFloat) -> String {
        "\(Double(value).formatted(.number.precision(.fractionLength(0...1)))) pt"
    }
}

/// The text roles with their size at the current Dynamic Type setting.
/// The same on both displays.
private struct TypeScaleCard: View {
    let typeSize: DynamicTypeSize

    private let roles: [(String, Font, UIFont.TextStyle)] = [
        ("screenTitle", DuoType.screenTitle, .largeTitle),
        ("sectionTitle", DuoType.sectionTitle, .title2),
        ("itemTitle", DuoType.itemTitle, .headline),
        ("body", DuoType.body, .body),
        ("secondary", DuoType.secondary, .subheadline),
        ("meta", DuoType.meta, .footnote),
        ("caption", DuoType.caption, .caption1)
    ]

    var body: some View {
        DuoCard {
            VStack(alignment: .leading, spacing: DuoSpace.x2) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Type scale")
                        .font(DuoType.itemTitle)
                    Text("\(Self.name(of: typeSize)). The same sizes closed and open.")
                        .font(DuoType.secondary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, DuoSpace.x1)
                ForEach(roles, id: \.0) { role in
                    HStack(alignment: .firstTextBaseline, spacing: DuoSpace.x3) {
                        Text("Battery 78%")
                            .font(role.1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Spacer(minLength: DuoSpace.x2)
                        Text("\(role.0) \(Int(Self.pointSize(role.2, at: typeSize).rounded())) pt")
                            .font(DuoType.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    static func pointSize(_ style: UIFont.TextStyle, at typeSize: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(typeSize))
        return UIFont.preferredFont(forTextStyle: style, compatibleWith: traits).pointSize
    }

    static func name(of typeSize: DynamicTypeSize) -> String {
        switch typeSize {
        case .xSmall: "Text size xSmall"
        case .small: "Text size Small"
        case .medium: "Text size Medium"
        case .large: "Text size Large, the default"
        case .xLarge: "Text size xLarge"
        case .xxLarge: "Text size xxLarge"
        case .xxxLarge: "Text size xxxLarge"
        default: "An accessibility text size"
        }
    }
}

// MARK: - Sample data

/// A made-up home with a 6 kWp solar array and a battery, on a Sunday in October.
private struct EnergyStat: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let value: String
    let unit: String
    let detail: String
    let tint: Color

    static let today: [EnergyStat] = [
        EnergyStat(id: "solar", title: "Solar", symbol: "sun.max.fill", value: "12.6", unit: "kWh",
                   detail: "Peak 3.9 kW at 12:40", tint: .orange),
        EnergyStat(id: "home", title: "Home used", symbol: "house.fill", value: "9.8", unit: "kWh",
                   detail: "1.2 kWh less than a usual Sunday", tint: .blue),
        EnergyStat(id: "battery", title: "Battery", symbol: "battery.75percent", value: "78", unit: "%",
                   detail: "Full by 14:10 at this rate", tint: .green),
        EnergyStat(id: "export", title: "Exported", symbol: "bolt.fill", value: "4.1", unit: "kWh",
                   detail: "Earned £0.62 today", tint: .purple)
    ]
}

private struct EnergyDevice: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let onStatus: String
    let tint: Color
    var isOn: Bool

    static let samples: [EnergyDevice] = [
        EnergyDevice(id: "heatpump", name: "Heat pump", symbol: "fan.fill",
                     onStatus: "Heating to 21.5 °C", tint: .orange, isOn: true),
        EnergyDevice(id: "car", name: "Car charger", symbol: "ev.charger.fill",
                     onStatus: "Starts at 00:30, off-peak", tint: .green, isOn: true),
        EnergyDevice(id: "dishwasher", name: "Dishwasher", symbol: "dishwasher.fill",
                     onStatus: "Eco, 1 h 50 min left", tint: .blue, isOn: true),
        EnergyDevice(id: "water", name: "Hot water", symbol: "drop.fill",
                     onStatus: "54 °C, boost on", tint: .red, isOn: false)
    ]
}
