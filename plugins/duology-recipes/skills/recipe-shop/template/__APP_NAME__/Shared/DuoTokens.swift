// The design token module from Duology's `duo-design-system` skill (references/tokens.md),
// unchanged. Every value follows the size class and Dynamic Type size of the view that
// reads it. Nothing here asks which device, display or screen the app runs on.

import SwiftUI

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

    /// System container margins (iOS 27.1). They can differ per side on iPhone Duo.
    /// Same helper as duo-layout's: keep one copy in the app.
    @ViewBuilder
    func duoContainerMargins() -> some View {
        if #available(iOS 27.1, *) {
            contentMargins(for: .container, edges: .horizontal)
        } else {
            padding(.horizontal)
        }
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
