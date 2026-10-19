import SwiftUI

// The design token module and grid helper from the `duo-design-system` skill
// (`references/tokens.md` and `references/grid.md`), used by the design tokens
// screen. Every value follows the size class and Dynamic Type size of the view
// that reads it. Nothing here asks which device, display or screen it runs on.
//
// The code is the skill's, copied on 19 October 2026, with one change: the
// skill's `duoContainerMargins()` is left out, because `containerMargins(_:)`
// in `FeedGrid.swift` is the same code with an edges parameter. The skill
// keeps the grid helper in a second file; here both live in this one.

/// Duology's 4-point spacing scale. The suffix is the number of 4-point steps.
nonisolated enum DuoSpace {
    static let x1: CGFloat = 4    // icon to badge, label to value
    static let x2: CGFloat = 8    // related items in a row
    static let x3: CGFloat = 12   // padding around a control with a bezel (HIG)
    static let x4: CGFloat = 16
    static let x5: CGFloat = 20
    static let x6: CGFloat = 24   // padding around a control without a bezel (HIG)
    static let x8: CGFloat = 32
    static let x10: CGFloat = 40
    static let x12: CGFloat = 48
}

/// Design tokens for one view. Read them with `@DuoMetrics`.
nonisolated struct DuoTokens: Equatable, Sendable {
    var isRegularWidth: Bool
    var isAccessibilitySize: Bool
    /// Longest comfortable line of body text, already scaled for Dynamic Type.
    var readableWidth: CGFloat

    init(widthClass: UserInterfaceSizeClass?,
         isAccessibilitySize: Bool = false,
         readableWidth: CGFloat = 600) {
        self.isRegularWidth = widthClass == .regular
        self.isAccessibilitySize = isAccessibilitySize
        self.readableWidth = readableWidth
    }

    /// Layout grid columns. Even in both size classes, so a fold never lands inside a column.
    var columns: Int { isRegularWidth ? 8 : 4 }
    var gutter: CGFloat { isRegularWidth ? DuoSpace.x4 : DuoSpace.x3 }
    var sectionSpacing: CGFloat { isRegularWidth ? DuoSpace.x8 : DuoSpace.x6 }
    var cardPadding: CGFloat { isRegularWidth ? DuoSpace.x5 : DuoSpace.x4 }
    /// Padding plus the inner radius, so nested corners stay concentric.
    var cardRadius: CGFloat { cardPadding + Self.innerRadius }

    /// Grid columns an item spans. Doubles at accessibility text sizes.
    func span(_ base: Int) -> Int { min(columns, isAccessibilitySize ? base * 2 : base) }

    static let minTouchTarget: CGFloat = 44        // HIG
    static let innerRadius: CGFloat = 8            // smallest radius, concentric fallback
    static let clearGlassDimming: Double = 0.35    // HIG, behind clear glass on bright media
}

/// Tokens for the view it sits in: `@DuoMetrics private var tokens`.
@propertyWrapper
struct DuoMetrics: DynamicProperty {
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var readableWidth: CGFloat = 600

    init() {}

    var wrappedValue: DuoTokens {
        DuoTokens(widthClass: widthClass,
                  isAccessibilitySize: typeSize.isAccessibilitySize,
                  readableWidth: readableWidth)
    }
}

/// Text roles. The same on both displays: the inner display shows more, not bigger.
nonisolated enum DuoType {
    static let screenTitle = Font.largeTitle.bold()
    static let sectionTitle = Font.title2.bold()
    static let itemTitle = Font.headline
    static let body = Font.body
    static let secondary = Font.subheadline
    static let meta = Font.footnote
    static let caption = Font.caption
}

/// Semantic colours. System colours already adapt to light, dark and Increase Contrast.
nonisolated enum DuoColor {
    static let background = Color(uiColor: .systemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let separator = Color(uiColor: .separator)

    /// A brand colour with light, dark and increased-contrast variants.
    static func dynamic(light: UIColor, dark: UIColor,
                        lightHighContrast: UIColor? = nil,
                        darkHighContrast: UIColor? = nil) -> Color {
        Color(uiColor: UIColor { traits in
            let high = traits.accessibilityContrast == .high
            if traits.userInterfaceStyle == .dark {
                return high ? (darkHighContrast ?? dark) : dark
            }
            return high ? (lightHighContrast ?? light) : light
        })
    }
}

extension View {
    /// A hit region of at least 44 x 44 pt around any content.
    func duoTouchTarget() -> some View {
        frame(minWidth: DuoTokens.minTouchTarget, minHeight: DuoTokens.minTouchTarget)
            .contentShape(.rect)
    }

    /// Caps a text column at a readable line length and centres it.
    func duoReadableWidth(_ tokens: DuoTokens) -> some View {
        frame(maxWidth: tokens.readableWidth).frame(maxWidth: .infinity)
    }

    /// Declares a rounded container shape for concentric children.
    /// Both branches read the same, but the compiler binds them to different
    /// overloads. In an app that deploys below iOS 26, only the first branch
    /// reaches the iOS 26 overload that `GeometryProxy.concentricCornerRadii` reads.
    @ViewBuilder
    func duoContainerShape(_ shape: RoundedRectangle) -> some View {
        if #available(iOS 26.0, *) {
            containerShape(shape)
        } else {
            containerShape(shape)
        }
    }
}

/// A content-layer card. Children can use `ConcentricRectangle` to match its corners.
struct DuoCard<Content: View>: View {
    @DuoMetrics private var tokens
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: tokens.cardRadius)
        content
            .padding(tokens.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            // The container shape goes before background(_:in:), or radii read nil.
            .duoContainerShape(shape)
            .background(DuoColor.card, in: shape)
    }
}

// MARK: - Grid helper (duo-design-system, references/grid.md)

/// A fold that runs top to bottom through a view, in that view's coordinates.
/// Only x values are kept, so scrolling never changes it.
nonisolated struct DuoFold: Equatable, Sendable {
    var minX: CGFloat
    var maxX: CGFloat
    var isActive: Bool

    init(minX: CGFloat, maxX: CGFloat, isActive: Bool) {
        self.minX = minX
        self.maxX = maxX
        self.isActive = isActive
    }

    /// The fold in `proxy`'s view, active or not. Nil on the outer display, when
    /// the fold runs side to side (held tall), or when it misses the view.
    @available(iOS 27.1, *)
    init?(_ proxy: GeometryProxy) {
        let folds = proxy.reservedRegions(kind: .division, options: .includeInactive)
        guard let fold = folds.first(where: \.isActive) ?? folds.first else { return nil }
        let frame = fold.frame
        guard frame.height > frame.width, frame.minX > 0, frame.maxX < proxy.size.width else {
            return nil
        }
        self.init(minX: frame.minX, maxX: frame.maxX, isActive: fold.isActive)
    }
}

/// What a grid needs to know about its own box. Equatable, so
/// `onGeometryChange` fires only when the width or the fold changes.
nonisolated struct DuoGridGeometry: Equatable, Sendable {
    var width: CGFloat = 0
    var fold: DuoFold?

    init() {}

    @available(iOS 27.1, *)
    init(_ proxy: GeometryProxy) {
        width = proxy.size.width
        fold = DuoFold(proxy)
    }
}

/// Column positions of a layout grid, in the grid's own coordinates.
nonisolated struct DuoColumns: Equatable, Sendable {
    struct Column: Equatable, Sendable {
        var x: CGFloat
        var width: CGFloat
        var maxX: CGFloat { x + width }
    }

    private(set) var columns: [Column]
    /// Index of the first column after the fold, or nil when the fold doesn't
    /// split the grid. Groups never cross it.
    private(set) var split: Int?

    /// With a fold, `count` is rounded down to even and each side of the fold gets
    /// half the columns. Flat, the gap at the fold is one gutter centred on it;
    /// partly folded, it is the fold's frame. If one side is too narrow for its
    /// half at `minimumColumn`, every column goes on the other side and the fold
    /// becomes the grid's edge.
    init(width: CGFloat, count: Int, gutter: CGFloat, fold: DuoFold? = nil,
         minimumColumn: CGFloat = 44) {
        guard let fold else {
            columns = Self.row(from: 0, to: width, count: max(1, count), gutter: gutter)
            split = nil
            return
        }
        let count = max(2, count - count % 2)
        let half = count / 2
        let gapStart = fold.isActive ? fold.minX : (fold.minX + fold.maxX - gutter) / 2
        let gapEnd = fold.isActive ? fold.maxX : gapStart + gutter
        // Decided on the fold's frame, which has the same size flat and folded,
        // so the choice doesn't flip when the phone folds.
        func holdsHalf(_ length: CGFloat) -> Bool {
            length - CGFloat(half - 1) * gutter >= CGFloat(half) * minimumColumn
        }
        if holdsHalf(fold.minX), holdsHalf(width - fold.maxX) {
            columns = Self.row(from: 0, to: gapStart, count: half, gutter: gutter)
                + Self.row(from: gapEnd, to: width, count: half, gutter: gutter)
            split = half
        } else if fold.minX > width - fold.maxX {
            columns = Self.row(from: 0, to: gapStart, count: count, gutter: gutter)
            split = nil
        } else {
            columns = Self.row(from: gapEnd, to: width, count: count, gutter: gutter)
            split = nil
        }
    }

    private static func row(from start: CGFloat, to end: CGFloat,
                            count: Int, gutter: CGFloat) -> [Column] {
        let each = max(0, (end - start - CGFloat(count - 1) * gutter) / CGFloat(count))
        return (0..<count).map { Column(x: start + CGFloat($0) * (each + gutter), width: each) }
    }

    /// Merges every `span` columns into one. Each side of the fold is grouped
    /// on its own, so no group crosses it.
    func grouped(by span: Int) -> DuoColumns {
        let span = max(1, span)
        guard span > 1, !columns.isEmpty else { return self }
        let sides = split.map { [columns[..<$0], columns[$0...]] } ?? [columns[...]]
        var result = self
        result.columns = []
        for (index, side) in sides.enumerated() {
            if index == 1 { result.split = result.columns.count }
            var start = side.startIndex
            while start < side.endIndex {
                let last = min(start + span, side.endIndex) - 1
                result.columns.append(Column(x: side[start].x, width: side[last].maxX - side[start].x))
                start += span
            }
        }
        return result
    }

    /// Empty space before the first column. Not zero only when the fold is the
    /// grid's leading edge. Put it on the grid as leading padding.
    var leadingInset: CGFloat { columns.first?.x ?? 0 }

    /// Items for `LazyVGrid`: fixed widths, and the real gap after each column.
    var gridItems: [GridItem] {
        guard let first = columns.first, first.width > 0 else {
            return Array(repeating: GridItem(.flexible()), count: max(1, columns.count))
        }
        return columns.indices.map { index in
            let next = index + 1 < columns.count ? columns[index + 1].x : columns[index].maxX
            return GridItem(.fixed(columns[index].width), spacing: next - columns[index].maxX)
        }
    }
}
