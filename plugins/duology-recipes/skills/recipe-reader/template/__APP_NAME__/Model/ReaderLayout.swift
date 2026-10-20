import CoreGraphics
import Foundation

/// Space around the text on a page.
nonisolated struct PageInsets: Equatable, Sendable {
    /// Above the text: the running head.
    var top: CGFloat = 40
    /// Below the text: the page number.
    var bottom: CGFloat = 36
    /// Left and right of the text, at least.
    var side: CGFloat = 24
    /// Lines longer than this are hard to read; wider pages get wider margins.
    var maxTextWidth: CGFloat = 600
    /// Between two pages when no fold separates them (a wide iPad window).
    var gutter: CGFloat = 32

    static let standard = PageInsets()
}

/// Where the pages go in the reader, from its size and the fold.
///
/// - A top-to-bottom fold, active or flat (open and held wide, or like a book): two
///   facing pages, one each side of the fold's frame.
/// - A side-to-side fold that is active (tabletop): one page above the fold, the
///   page turns below it.
/// - Anything else (closed, held tall and flat, Split View): one page. A wide
///   regular-width window with no fold (iPad) gets two pages with a gutter.
///
/// Both pages of a spread share one size, the narrower side's, so one pagination
/// serves both. Pure geometry, tested on the Mac.
nonisolated struct ReaderLayout: Equatable, Sendable {
    nonisolated enum Mode: String, Sendable {
        case single, spread, tabletop
    }

    let mode: Mode
    /// Each page's region (running head, text and page number): one, or two in a spread.
    let regions: [CGRect]
    /// The size of every page's text: what the paginator lays out. Zero when too small to read.
    let pageSize: CGSize
    /// Tabletop only: the stable region below the fold, for the page turns.
    let controls: CGRect?
    let insets: PageInsets

    var perSpread: Int { mode == .spread ? 2 : 1 }

    init(size: CGSize, fold: FoldGeometry, prefersSpread: Bool, insets: PageInsets = .standard) {
        self.insets = insets
        let bounds = CGRect(origin: .zero, size: size)
        var controls: CGRect?
        if let f = fold.frame, Self.crossesMiddle(f, vertical: fold.isVertical, of: size) {
            if fold.isVertical {
                mode = .spread
                regions = [CGRect(x: 0, y: 0, width: f.minX, height: size.height),
                           CGRect(x: f.maxX, y: 0, width: size.width - f.maxX, height: size.height)]
            } else if fold.isActive {
                mode = .tabletop
                regions = [CGRect(x: 0, y: 0, width: size.width, height: f.minY)]
                controls = CGRect(x: 0, y: f.maxY, width: size.width, height: size.height - f.maxY)
            } else {
                mode = .single
                regions = [bounds]
            }
        } else if prefersSpread, size.width > size.height {
            let half = (size.width - insets.gutter) / 2
            mode = .spread
            regions = [CGRect(x: 0, y: 0, width: half, height: size.height),
                       CGRect(x: size.width - half, y: 0, width: half, height: size.height)]
        } else {
            mode = .single
            regions = [bounds]
        }
        self.controls = controls
        let width = min((regions.map(\.width).min() ?? 0) - 2 * insets.side, insets.maxTextWidth)
        let height = (regions.map(\.height).min() ?? 0) - insets.top - insets.bottom
        pageSize = width >= 44 && height >= 44 ? CGSize(width: width, height: height) : .zero
    }

    /// The text's frame in a region: centred across it, below the running head.
    func textFrame(in region: CGRect) -> CGRect {
        CGRect(x: region.midX - pageSize.width / 2, y: region.minY + insets.top,
               width: pageSize.width, height: pageSize.height)
    }

    /// A fold counts only when it crosses the middle half of the reader. A fold at
    /// the very edge (a window beside it in Split View) would leave a sliver of a page.
    static func crossesMiddle(_ fold: CGRect, vertical: Bool, of size: CGSize) -> Bool {
        let line = vertical ? fold.midX : fold.midY
        let length = vertical ? size.width : size.height
        return line > length / 4 && line < length * 3 / 4
    }
}
