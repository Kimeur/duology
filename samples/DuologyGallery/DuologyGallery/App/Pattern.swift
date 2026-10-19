import SwiftUI

/// The screens in the gallery: the eight layout patterns from `duo-patterns`,
/// then three screens added in v0.2 for poses, fold transitions and design
/// tokens. The raw values are the names the `-pattern` launch argument takes.
enum Pattern: String, CaseIterable, Identifiable {
    case listDetail
    case supportingPane
    case twoPage
    case dualView
    case extendedCanvas
    case feedReflow
    case tabsToSidebar
    case displacement
    case tabletopPlayer
    case foldTransition
    case designTokens

    var id: String { rawValue }

    /// The eight layout patterns, in the order `duo-patterns` lists them.
    static let layoutPatterns: [Pattern] = [
        .listDetail, .supportingPane, .twoPage, .dualView,
        .extendedCanvas, .feedReflow, .tabsToSidebar, .displacement
    ]

    /// Screens for the v0.2 design skills: `duo-postures`, `duo-transitions`
    /// with `duo-continuity`, and `duo-design-system`.
    static let designScreens: [Pattern] = [.tabletopPlayer, .foldTransition, .designTokens]

    var title: String {
        switch self {
        case .listDetail: "List-detail"
        case .supportingPane: "Supporting pane"
        case .twoPage: "Two-page"
        case .dualView: "Dual view"
        case .extendedCanvas: "Extended canvas"
        case .feedReflow: "Feed reflow"
        case .tabsToSidebar: "Tabs to sidebar"
        case .displacement: "Displacement"
        case .tabletopPlayer: "Tabletop player"
        case .foldTransition: "Fold transition"
        case .designTokens: "Design tokens"
        }
    }

    /// One line: the kind of screen this pattern suits.
    var useItFor: String {
        switch self {
        case .listDetail: "Mail, messages, notes, settings"
        case .supportingPane: "Comments, transcripts, tools, up next"
        case .twoPage: "Books, documents, slides"
        case .dualView: "List and map, text and preview"
        case .extendedCanvas: "Maps, drawing, big tables"
        case .feedReflow: "Photos, shops, news"
        case .tabsToSidebar: "Apps with many sections"
        case .displacement: "Controls you place near the middle"
        case .tabletopPlayer: "Video, calls, recipes, workouts"
        case .foldTransition: "Readers, maps, editors: work in progress"
        case .designTokens: "Grids, margins, type and touch targets"
        }
    }

    /// What the demo is, in the words of its sample content.
    var demo: String {
        switch self {
        case .listDetail: "An inbox"
        case .supportingPane: "An article with its discussion"
        case .twoPage: "A short book"
        case .dualView: "A day of places, as a list and a map"
        case .extendedCanvas: "A trail map you can pan and sketch on"
        case .feedReflow: "A homeware shop"
        case .tabsToSidebar: "A music library"
        case .displacement: "Voice memos with a record button"
        case .tabletopPlayer: "A nature film with one set of controls"
        case .foldTransition: "A field guide that keeps your place"
        case .designTokens: "A home energy dashboard on its grid"
        }
    }

    var closed: String {
        switch self {
        case .listDetail: "The list, then the message"
        case .supportingPane: "The article; discussion in a sheet"
        case .twoPage: "One page"
        case .dualView: "List or map, with a switch"
        case .extendedCanvas: "The map, tools at the bottom"
        case .feedReflow: "As many columns as fit"
        case .tabsToSidebar: "A tab bar on the side"
        case .displacement: "Controls at the bottom"
        case .tabletopPlayer: "The film above the controls"
        case .foldTransition: "The article, tools at the bottom"
        case .designTokens: "4 columns, 12 pt gutters"
        }
    }

    var open: String {
        switch self {
        case .listDetail: "List and message side by side"
        case .supportingPane: "Article with a narrower pane"
        case .twoPage: "Two pages, gap on the fold"
        case .dualView: "Both, kept in sync"
        case .extendedCanvas: "The map spans the fold"
        case .feedReflow: "An even number of columns"
        case .tabsToSidebar: "A sidebar"
        case .displacement: "Same place flat; off the fold when folded"
        case .tabletopPlayer: "Film on one side of the fold, controls on the other"
        case .foldTransition: "Same column, place and tools; contents beside"
        case .designTokens: "8 columns; the middle gutter on the fold"
        }
    }

    /// The caption over the second diagram on the home screen.
    var openCaption: String {
        switch self {
        case .tabletopPlayer: "Folded"
        default: "Open"
        }
    }

    /// The main Apple API the screen is built on.
    var api: String {
        switch self {
        case .listDetail: "NavigationSplitView"
        case .supportingPane: "ArrangementView"
        case .twoPage: "reservedRegions"
        case .dualView: "ArrangementView"
        case .extendedCanvas: "reservedRegions"
        case .feedReflow: "LazyVGrid"
        case .tabsToSidebar: "defaultTabBarPlacement"
        case .displacement: "reservedRegions"
        case .tabletopPlayer: "reservedRegions"
        case .foldTransition: "ScrollViewReader"
        case .designTokens: "contentMargins"
        }
    }

    var symbol: String {
        switch self {
        case .listDetail: "list.bullet.rectangle"
        case .supportingPane: "sidebar.right"
        case .twoPage: "book.pages"
        case .dualView: "map"
        case .extendedCanvas: "scribble.variable"
        case .feedReflow: "square.grid.2x2"
        case .tabsToSidebar: "sidebar.left"
        case .displacement: "arrow.left.and.right.square"
        case .tabletopPlayer: "play.rectangle.fill"
        case .foldTransition: "text.book.closed"
        case .designTokens: "ruler"
        }
    }

    var tint: Color {
        switch self {
        case .listDetail: Color(hex: 0x2B55C7)
        case .supportingPane: Color(hex: 0x7A4CD9)
        case .twoPage: Color(hex: 0xC2410C)
        case .dualView: Color(hex: 0x0F8A6A)
        case .extendedCanvas: Color(hex: 0x3F7D20)
        case .feedReflow: Color(hex: 0xC0266D)
        case .tabsToSidebar: Color(hex: 0xD9480F)
        case .displacement: Color(hex: 0x0E7490)
        case .tabletopPlayer: Color(hex: 0xBE123C)
        case .foldTransition: Color(hex: 0xA16207)
        case .designTokens: Color(hex: 0x4338CA)
        }
    }

    @ViewBuilder
    var screen: some View {
        switch self {
        case .listDetail: ListDetailView()
        case .supportingPane: SupportingPaneView()
        case .twoPage: TwoPageView()
        case .dualView: DualView()
        case .extendedCanvas: ExtendedCanvasView()
        case .feedReflow: FeedReflowView()
        case .tabsToSidebar: TabsToSidebarView()
        case .displacement: DisplacementView()
        case .tabletopPlayer: TabletopPlayerView()
        case .foldTransition: FoldTransitionView()
        case .designTokens: DesignTokensView()
        }
    }
}
