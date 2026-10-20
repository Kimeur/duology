# PDFs, and the reader in UIKit

## PDFs

PDF pages have a fixed layout, so nothing reflows. The place is a page index (plus a point on the page if you need it), and a fold only changes how big the page is drawn.

PDFKit has a two-up mode: `displayMode = .twoUp` shows two pages side by side, and `displaysAsBook = true` puts the first page alone, like a cover ([`displayMode`](https://developer.apple.com/documentation/pdfkit/pdfview/displaymode), [`displaysAsBook`](https://developer.apple.com/documentation/pdfkit/pdfview/displaysasbook)). PDFKit lays the spread out around the middle of its own view (*measured*, below). On iPhone Duo the middle of your view is often not the fold: held wide with the bar on the trailing side, it was 22 pt left of the fold (*measured*, [fold-geometry.md](fold-geometry.md)). So frame the `PDFView` symmetrically around the fold line.

```swift
import PDFKit
import SwiftUI

// requires: FoldGeometry (references/fold-geometry.md)

/// A PDF shown two-up when a top-to-bottom fold crosses the view, one page otherwise.
/// PDFKit centres a two-up spread in its own view, so the view is centred on the fold.
@available(iOS 27.1, *)
struct PDFSpread: View {
    let document: PDFDocument
    @State private var fold = FoldGeometry()
    @State private var size = CGSize.zero

    var body: some View {
        // Widest frame whose middle is the fold line: the gutter then lies on the fold.
        let line = fold.isVertical ? (fold.frame?.midX ?? size.width / 2) : size.width / 2
        let half = min(line, size.width - line)
        PDFKitView(document: document, twoUp: fold.isVertical)
            .frame(width: 2 * half)
            .position(x: line, y: size.height / 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onFoldChange { fold = $0 }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    var twoUp: Bool

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displaysAsBook = false     // true puts the cover alone in the middle, across the fold
        view.document = document
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        let mode: PDFDisplayMode = twoUp ? .twoUp : .singlePageContinuous
        guard view.displayMode != mode else { return }
        let page = view.currentPage     // keep the page the reader is on
        view.displayMode = mode
        if let page { view.go(to: page) }
    }
}
```

- Two-up only when a top-to-bottom fold crosses the view: open and held wide, or book. Closed, held tall and in tabletop, one page at a time, scrolling.
- The symmetric frame leaves a strip on one side, where the bar is. Fill it with the same background.
- PDFKit leaves only a small gap between the two pages, so the inner edges of both pages sit inside the 40 pt fold frame. Most PDF pages have white margins there, like a printed book's gutter. Check your documents in book pose.
- `displaysAsBook = true` shows the first page alone, like a printed book's cover. In two-up on iPhone Duo that cover sat in the middle of the view, across the fold (*measured*). With `false`, every spread has one page on each side. Keep `true` only for documents whose left and right pages matter, and accept the centred cover.
- `go(to:)` after switching modes keeps the reader on the spread's leading page.

What we measured (iPhone Duo simulator, iOS 27.1, an eight-page PDF opened at page 3):

| Pose | `PDFView` frame | Mode | On screen |
|---|---|---|---|
| Open, held wide, and book | 783 × 635 pt, centred on the fold at x = 475.5 | `.twoUp` | pages 3 and 4 (`displaysAsBook = false`), or 2 and 3 (`true`); the gap between them, about 9 pt, at x = 471 to 480 |
| Open or book, at the start of the document, `displaysAsBook = true` | same | `.twoUp` | page 1 alone, centred across the fold |
| Tabletop | 669 × 835 pt | `.singlePageContinuous` | page 2: the leading page of the last spread |

The 783 pt frame is twice the distance from the fold to the trailing edge of the safe area (867 pt; the status bar column took 84 pt). It left an empty 84 pt strip at the leading edge.
- A selection in a `PDFView` stays inside that view, like a page of text ([`currentSelection`](https://developer.apple.com/documentation/pdfkit/pdfview/currentselection)).

## The reader in UIKit

Same `Paginator`, same rules. `SpreadView` places two TextKit 1 text views from the fold in `layoutSubviews`. UIKit calls `layoutSubviews` again when the fold turns active or inactive (*measured* in `duo-postures`), and when the size changes.

```swift
import UIKit

// requires: PageBreaks, Paginator (SKILL.md)

/// UIKit: two pages split at the fold, or one page. layoutSubviews reads the fold,
/// and UIKit runs it again when the fold turns active or inactive.
@available(iOS 27.1, *)
final class SpreadView: UIView {
    let pages = [UITextView(usingTextLayoutManager: false), UITextView(usingTextLayoutManager: false)]
    var margin: CGFloat = 20
    /// Called with the new page size. Paginate again, then fill both pages.
    var onPageSizeChange: ((CGSize) -> Void)?
    private(set) var isSpread = false
    private var pageSize = CGSize.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        for page in pages {
            page.isEditable = false
            page.isScrollEnabled = false
            page.textContainerInset = .zero
            page.textContainer.lineFragmentPadding = 0
            page.backgroundColor = .clear
            addSubview(page)
        }
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        // A top-to-bottom fold with part of this view on each side, active or not.
        let fold = reservedRegions(kind: .division, options: .includeInactive)
            .map(\.frame)
            .first { $0.height > $0.width && $0.minX > 0 && $0.maxX < bounds.width }
        isSpread = fold != nil || (traitCollection.horizontalSizeClass == .regular && bounds.width > bounds.height)
        let spine = fold ?? CGRect(x: bounds.midX - 16, y: 0, width: 32, height: bounds.height)
        let regions = isSpread
            ? [CGRect(x: 0, y: 0, width: spine.minX, height: bounds.height),
               CGRect(x: spine.maxX, y: 0, width: bounds.width - spine.maxX, height: bounds.height)]
            : [bounds, .zero]
        let width = isSpread ? min(regions[0].width, regions[1].width) : bounds.width
        let size = CGSize(width: max(width - 2 * margin, 0), height: max(bounds.height - 2 * margin, 0))
        for (page, region) in zip(pages, regions) {
            page.isHidden = region.isEmpty
            page.frame = CGRect(x: region.midX - size.width / 2, y: region.midY - size.height / 2,
                                width: size.width, height: size.height)
        }
        if size != pageSize {
            pageSize = size
            onPageSizeChange?(size)
        }
    }
}
```

- Owner: in `onPageSizeChange`, rebuild the text at the trait collection's content size, paginate, then set `pages[0].attributedText` and, if `isSpread`, `pages[1].attributedText` to the two page ranges that hold the saved offset.
- Debounce like the SwiftUI reader: a fold sends several sizes in a row.
- Add the tabletop case the same way as `PagedReader`: an active fold whose frame is wider than tall puts the page above it.
- Listen for Dynamic Type with `registerForTraitChanges([UITraitPreferredContentSizeCategory.self])` and paginate again ([Adapting your app when traits change](https://developer.apple.com/documentation/uikit/adapting-your-app-when-traits-change)).

### UIPageViewController

`UIPageViewController` with `.pageCurl` and a `.mid` spine shows two pages around the middle of its view ([`SpineLocation`](https://developer.apple.com/documentation/uikit/uipageviewcontroller/spinelocation-swift.enum)). Two problems on iPhone Duo:

1. The spine follows the view's middle, not the fold. Frame the controller's view symmetrically around the fold, as with PDFKit.
2. Its delegate picks the spine from an interface orientation (`pageViewController(_:spineLocationFor:)`). The inner display ignores your supported orientations ([talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=222)), and opening the phone is not a rotation. Whether that delegate method runs on fold or unfold is unverified. Prefer `SpreadView` or the SwiftUI reader, which read the fold directly.
