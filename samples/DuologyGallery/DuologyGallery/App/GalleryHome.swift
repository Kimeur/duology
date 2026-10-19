import SwiftUI

/// The gallery's home: every pattern, each with what it is for and how it
/// behaves closed and open. The grid itself follows the feed reflow rules,
/// so it shows an even number of columns on the inner display.
struct GalleryHome: View {
    @Binding var openPattern: Pattern?
    @Binding var showsRegions: Bool

    @State private var grid = FeedGridInput()
    @State private var viewSize = CGSize.zero
    @State private var fold = FoldGeometry()
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.verticalSizeClass) private var heightClass
    @ScaledMetric(relativeTo: .body) private var minCardWidth = 340.0
    private let spacing: CGFloat = 16

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro
                    cards(Pattern.layoutPatterns)
                        .onFeedGridChange { grid = $0 }
                    designHeader
                    cards(Pattern.designScreens)
                    footer
                }
                .containerMargins(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { viewSize = $0 }
            .onFoldChange { fold = $0 }
            .navigationTitle("Duology Gallery")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Toggle(isOn: $showsRegions) {
                        Label("Show Reserved Regions", systemImage: "rectangle.dashed")
                    }
                    .toggleStyle(.button)
                    .accessibilityHint("Draws the fold and camera regions over every pattern")
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Eight layout patterns for iPhone Duo. Open each one closed, open, and partly folded in Device Hub, and watch what moves.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            WindowFacts(size: viewSize, widthClass: widthClass, heightClass: heightClass, fold: fold)
        }
    }

    private func cards(_ patterns: [Pattern]) -> some View {
        LazyVGrid(columns: feedColumns(for: grid, minTileWidth: minCardWidth, spacing: spacing),
                  alignment: .leading, spacing: spacing) {
            ForEach(patterns) { pattern in
                Button {
                    openPattern = pattern
                } label: {
                    PatternCard(pattern: pattern)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the \(pattern.title) demo")
            }
        }
    }

    /// The v0.2 screens: one each for poses, fold transitions and design tokens.
    private var designHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Poses, transitions and tokens")
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text("A tabletop player, a reader that keeps your place through a fold, and the design tokens drawn over a real screen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var footer: some View {
        Text("Part of Duology, an MIT-licensed Claude Code plugin pack. Every API in these screens was checked against the iOS 27.1 SDK.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }
}

/// What this window looks like right now. Handy when you switch poses in Device Hub.
private struct WindowFacts: View {
    let size: CGSize
    let widthClass: UserInterfaceSizeClass?
    let heightClass: UserInterfaceSizeClass?
    let fold: FoldGeometry

    var body: some View {
        // One row when it fits, two rows of two otherwise, one column as a last resort.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { sizeChips; layoutChips }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) { sizeChips }
                HStack(spacing: 8) { layoutChips }
            }
            VStack(alignment: .leading, spacing: 8) { sizeChips; layoutChips }
        }
        .font(.footnote.weight(.medium))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var sizeChips: some View {
        FactChip(symbol: "rectangle.portrait", text: "View \(Int(size.width)) × \(Int(size.height)) pt")
        FactChip(symbol: "rectangle.split.2x1", text: fold.frame == nil ? "No fold" : (fold.isActive ? "Fold active" : "Fold flat"))
    }

    @ViewBuilder
    private var layoutChips: some View {
        FactChip(symbol: "arrow.left.and.right", text: "Width \(name(widthClass))")
        FactChip(symbol: "arrow.up.and.down", text: "Height \(name(heightClass))")
    }

    private func name(_ sizeClass: UserInterfaceSizeClass?) -> String {
        switch sizeClass {
        case .compact: "compact"
        case .regular: "regular"
        default: "unknown"
        }
    }
}

private struct FactChip: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
    }
}

/// One pattern on the home screen.
private struct PatternCard: View {
    let pattern: Pattern

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: pattern.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(pattern.tint.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(pattern.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Use it for: \(pattern.useItFor)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }

            HStack(alignment: .top, spacing: 12) {
                DiagramColumn(caption: "Closed", detail: pattern.closed) {
                    ClosedDiagram(pattern: pattern)
                }
                DiagramColumn(caption: pattern.openCaption, detail: pattern.open) {
                    OpenDiagram(pattern: pattern)
                }
            }

            HStack(spacing: 6) {
                Text(pattern.demo)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(pattern.api)
                    .font(.caption.monospaced().weight(.medium))
                    .foregroundStyle(pattern.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(pattern.tint.opacity(0.12), in: Capsule())
            }
            .font(.footnote)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct DiagramColumn<Diagram: View>: View {
    let caption: String
    let detail: String
    @ViewBuilder var diagram: () -> Diagram

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            diagram()
            Text(caption)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Diagrams

/// The outer display: one portrait screen.
private struct ClosedDiagram: View {
    let pattern: Pattern

    var body: some View {
        DiagramHalf(glyph: closedGlyph, tint: pattern.tint)
            .frame(width: 46, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color(.separator), lineWidth: 1))
            .frame(height: 66)
            .accessibilityHidden(true)
    }

    private var closedGlyph: DiagramGlyph {
        switch pattern {
        case .listDetail: .list
        case .supportingPane: .text
        case .twoPage: .page
        case .dualView: .list
        case .extendedCanvas: .trail(.whole)
        case .feedReflow: .grid
        case .tabsToSidebar: .sideTabs
        case .displacement: .memos(controls: true)
        case .tabletopPlayer: .film(controls: true)
        case .foldTransition: .reading
        case .designTokens: .columns(4)
        }
    }
}

/// The inner display: two physical halves either side of the fold.
/// `EvenSplit` fits here: both halves must always show.
private struct OpenDiagram: View {
    let pattern: Pattern

    var body: some View {
        EvenSplit(spacing: 1.5) {
            DiagramHalf(glyph: glyphs.0, tint: pattern.tint)
        } secondary: {
            DiagramHalf(glyph: glyphs.1, tint: pattern.tint)
        }
        .background(Color(.separator))
        .frame(width: 94, height: 66)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color(.separator), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var glyphs: (DiagramGlyph, DiagramGlyph) {
        switch pattern {
        case .listDetail: (.list, .detail)
        case .supportingPane: (.text, .bubbles)
        case .twoPage: (.page, .page)
        case .dualView: (.list, .map)
        case .extendedCanvas: (.trail(.left), .trail(.right))
        case .feedReflow: (.grid, .grid)
        case .tabsToSidebar: (.sidebar, .text)
        case .displacement: (.memos(controls: false), .memos(controls: true))
        case .tabletopPlayer: (.film(controls: false), .controls)
        case .foldTransition: (.contents, .reading)
        case .designTokens: (.columns(4), .columns(4))
        }
    }
}

private enum TrailPart { case whole, left, right }

private enum DiagramGlyph {
    case list, detail, text, bubbles, page, map, grid, sidebar, sideTabs
    case trail(TrailPart)
    case memos(controls: Bool)
    case film(controls: Bool), controls, reading, contents
    case columns(Int)
}

private struct DiagramHalf: View {
    let glyph: DiagramGlyph
    let tint: Color

    var body: some View {
        ZStack {
            Color(.tertiarySystemGroupedBackground)
            content.padding(5)
        }
    }

    private var line: Color { Color(.tertiaryLabel) }

    @ViewBuilder
    private var content: some View {
        switch glyph {
        case .list:
            VStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    HStack(spacing: 3) {
                        Circle().fill(index == 1 ? tint : line).frame(width: 5, height: 5)
                        Capsule().fill(line).frame(height: 2.5)
                    }
                }
                Spacer(minLength: 0)
            }
        case .detail:
            VStack(alignment: .leading, spacing: 4) {
                Capsule().fill(tint).frame(width: 22, height: 4)
                ForEach(0..<4, id: \.self) { index in
                    Capsule().fill(line).frame(maxWidth: index == 3 ? 20 : .infinity).frame(height: 2.5)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .text:
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 2).fill(tint.opacity(0.35)).frame(height: 12)
                ForEach(0..<4, id: \.self) { index in
                    Capsule().fill(line).frame(maxWidth: index == 3 ? 18 : .infinity).frame(height: 2.5)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .bubbles:
            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index == 3 ? tint : tint.opacity(0.3))
                        .frame(width: index.isMultiple(of: 2) ? 30 : 22, height: 7)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .page:
            VStack(alignment: .leading, spacing: 4) {
                Capsule().fill(tint).frame(width: 16, height: 3.5)
                ForEach(0..<6, id: \.self) { index in
                    Capsule().fill(line).frame(maxWidth: index == 5 ? 14 : .infinity).frame(height: 2)
                }
                Spacer(minLength: 0)
            }
            .padding(3)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 2))
        case .map:
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(tint.opacity(0.14))
                Path { path in
                    path.move(to: CGPoint(x: 2, y: 40))
                    path.addCurve(to: CGPoint(x: 34, y: 8), control1: CGPoint(x: 18, y: 42), control2: CGPoint(x: 14, y: 10))
                }
                .stroke(Color(.systemBackground), lineWidth: 2)
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index == 1 ? tint : line)
                        .frame(width: 6, height: 6)
                        .offset(x: [-8, 4, 10][index], y: [10, -4, -14][index])
                }
            }
        case .grid:
            Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                ForEach(0..<3, id: \.self) { row in
                    GridRow {
                        ForEach(0..<2, id: \.self) { column in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(tint.opacity((row + column).isMultiple(of: 2) ? 0.45 : 0.25))
                        }
                    }
                }
            }
        case .sidebar:
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule().fill(index == 0 ? tint : line).frame(height: 2.5)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 14)
                .padding(3)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 2))
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(tint.opacity(0.35)).frame(height: 12)
                    Capsule().fill(line).frame(height: 2.5)
                    Spacer(minLength: 0)
                }
            }
        case .sideTabs:
            HStack(spacing: 4) {
                VStack(spacing: 5) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle().fill(index == 0 ? tint : line).frame(width: 4, height: 4)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(tint.opacity(0.35)).frame(height: 12)
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule().fill(line).frame(height: 2.5)
                    }
                    Spacer(minLength: 0)
                }
            }
        case .trail(let part):
            TrailGlyph(part: part, tint: tint)
        case .film(let controls):
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [tint.opacity(0.55), tint.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(maxHeight: .infinity)
                    .overlay(Image(systemName: "play.fill").font(.system(size: 7)).foregroundStyle(.white))
                if controls {
                    Capsule()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(height: 8)
                        .overlay(Capsule().fill(tint).frame(width: 10, height: 2.5))
                        .shadow(color: .black.opacity(0.15), radius: 1.5, y: 1)
                }
            }
        case .controls:
            VStack(spacing: 4) {
                Spacer(minLength: 0)
                Capsule().fill(line).frame(height: 2.5)
                HStack(spacing: 4) {
                    Circle().fill(line).frame(width: 4, height: 4)
                    Circle().fill(tint).frame(width: 8, height: 8)
                    Circle().fill(line).frame(width: 4, height: 4)
                }
                Spacer(minLength: 0)
            }
            .padding(4)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 3))
        case .reading:
            ZStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Capsule().fill(tint).frame(width: 18, height: 3.5)
                    ForEach(0..<5, id: \.self) { index in
                        Capsule()
                            .fill(index == 2 ? Color.yellow.opacity(0.8) : line)
                            .frame(maxWidth: index == 4 ? 16 : .infinity)
                            .frame(height: 2.5)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Capsule()
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 24, height: 8)
                    .shadow(color: .black.opacity(0.15), radius: 1.5, y: 1)
            }
        case .contents:
            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 1).fill(index == 3 ? tint : line).frame(width: 4, height: 4)
                        Capsule().fill(line).frame(height: 2.5)
                    }
                }
                Spacer(minLength: 0)
            }
        case .columns(let count):
            HStack(spacing: 2) {
                ForEach(0..<count, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1).fill(tint.opacity(0.28))
                }
            }
            .overlay(alignment: .top) {
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(.secondarySystemGroupedBackground)).frame(height: 9)
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2).fill(Color(.secondarySystemGroupedBackground))
                        RoundedRectangle(cornerRadius: 2).fill(Color(.secondarySystemGroupedBackground))
                    }
                    .frame(height: 9)
                }
                .padding(.top, 3)
            }
        case .memos(let controls):
            ZStack(alignment: .bottom) {
                VStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { _ in
                        Capsule().fill(line).frame(height: 2.5)
                    }
                    Spacer(minLength: 0)
                }
                if controls {
                    Capsule()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 26, height: 11)
                        .overlay(Circle().fill(.red).frame(width: 6, height: 6))
                        .shadow(color: .black.opacity(0.15), radius: 1.5, y: 1)
                }
            }
        }
    }
}

/// A trail drawn across both halves, so the open diagram reads as one canvas.
private struct TrailGlyph: View {
    let part: TrailPart
    let tint: Color

    var body: some View {
        Canvas { context, size in
            // The trail is defined over two half-widths. Each half draws its share.
            let total = CGSize(width: part == .whole ? size.width : size.width * 2, height: size.height)
            let shift: CGFloat = part == .right ? -size.width : 0
            var rings = Path()
            for ring in 1...3 {
                let radius = CGFloat(ring) * total.height * 0.16
                rings.addEllipse(in: CGRect(x: total.width * 0.62 - radius * 1.3 + shift,
                                            y: total.height * 0.42 - radius,
                                            width: radius * 2.6, height: radius * 2))
            }
            context.stroke(rings, with: .color(tint.opacity(0.35)), lineWidth: 1)
            var trail = Path()
            trail.move(to: CGPoint(x: total.width * 0.06 + shift, y: total.height * 0.86))
            trail.addCurve(to: CGPoint(x: total.width * 0.62 + shift, y: total.height * 0.42),
                           control1: CGPoint(x: total.width * 0.32 + shift, y: total.height * 0.95),
                           control2: CGPoint(x: total.width * 0.30 + shift, y: total.height * 0.30))
            trail.addCurve(to: CGPoint(x: total.width * 0.95 + shift, y: total.height * 0.14),
                           control1: CGPoint(x: total.width * 0.85 + shift, y: total.height * 0.50),
                           control2: CGPoint(x: total.width * 0.80 + shift, y: total.height * 0.16))
            context.stroke(trail, with: .color(tint), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 2]))
        }
    }
}
