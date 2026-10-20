# PagedReader: full code

The reader from SKILL.md. It needs `FoldGeometry` ([fold-geometry.md](fold-geometry.md)) and `PageBreaks` and `Paginator` (SKILL.md). Everything here typechecks against the iOS 27.1 simulator SDK in Swift 5 and Swift 6 mode, with main-actor default isolation, and with an iOS 26.0 deployment target.

## PageTextView

One page. It uses TextKit 1, like the paginator. A TextKit 2 text view can break lines a little differently from TextKit 1, and the last line of a page would then spill over. `UITextView(usingTextLayoutManager: false)` is iOS 16 ([doc](https://developer.apple.com/documentation/uikit/uitextview/init(usingtextlayoutmanager:))).

```swift
import SwiftUI
import UIKit

/// One page of text, laid out by TextKit 1 like the paginator, so a page never
/// overflows. Selectable, not editable, no scrolling.
struct PageTextView: UIViewRepresentable {
    let text: NSAttributedString
    /// Called with the selected text when the reader picks "Add to Notes".
    var onQuote: (@MainActor (String) -> Void)? = nil

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView(usingTextLayoutManager: false)   // TextKit 1, same engine as Paginator
        view.isEditable = false
        view.isScrollEnabled = false
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0              // same as Paginator
        view.backgroundColor = .clear
        view.adjustsFontForContentSizeCategory = false          // the text already has the reader's size
        view.textDragInteraction?.isEnabled = true              // drag a quote to the notes (already true on the simulator)
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.onQuote = onQuote
        if view.attributedText != text { view.attributedText = text }
    }

    /// Take exactly the size SwiftUI offers: the page size the text was paginated for.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onQuote: (@MainActor (String) -> Void)?

        @available(iOS 26.0, *)
        func textView(_ textView: UITextView, editMenuForTextInRanges ranges: [NSValue],
                      suggestedActions: [UIMenuElement]) -> UIMenu? {
            let text = textView.text as NSString
            let quote = ranges.map { text.substring(with: $0.rangeValue) }.joined(separator: " ")
            guard let onQuote, !quote.isEmpty else { return nil }    // nil keeps the system menu
            let add = UIAction(title: String(localized: "Add to Notes"),
                               image: UIImage(systemName: "note.text.badge.plus")) { _ in onQuote(quote) }
            return UIMenu(children: [add] + suggestedActions)   // first: the menu shows only a few items before it pages
        }
    }
}
```

- `sizeThatFits(_:uiView:context:)` returns the size SwiftUI offers. Without it, a non-scrolling text view reports its text's height and fights the page frame.
- `textView(_:editMenuForTextInRanges:suggestedActions:)` is iOS 26 ([doc](https://developer.apple.com/documentation/uikit/uitextviewdelegate/textview(_:editmenufortextinranges:suggestedactions:))). It replaces the single-range method from iOS 16, which the SDK marks to be deprecated.
- Put your action first. *Measured:* the system offered eight suggested actions; with Add to Notes appended after them, the menu's first page showed only Copy, Look Up, Translate and Search Web, and Add to Notes sat on a later page.
- The text has `UIColor.label`, so dark mode works with a clear background.

## PagedReader

```swift
import SwiftUI
import UIKit

// requires: FoldGeometry (references/fold-geometry.md)
// requires: PageBreaks, Paginator (SKILL.md), PageTextView (this file)

nonisolated struct Chapter: Identifiable, Hashable, Sendable {
    let id: String
    let text: String
}

/// One page closed. Two facing pages when a top-to-bottom fold crosses the view (open
/// and held wide, or book). Tabletop: the page above the fold, page turns below it.
/// The place is a character offset, so it survives every fold, rotation and text size.
@available(iOS 27.1, *)
struct PagedReader: View {
    let chapter: Chapter
    @Binding var offset: Int                  // owned above the reader: a model or @SceneStorage
    var onQuote: (@MainActor (String) -> Void)? = nil

    @State private var fold = FoldGeometry()
    @State private var size = CGSize.zero
    @State private var text = NSAttributedString()
    @State private var breaks = PageBreaks()
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.dynamicTypeSize) private var typeSize

    private let margin: CGFloat = 20

    private enum Mode { case single, spread, tabletop }

    private var mode: Mode {
        if fold.frame != nil {
            if fold.isVertical { return .spread }          // book, or open and held wide
            return fold.isActive ? .tabletop : .single     // tabletop, or open, flat and held tall
        }
        return widthClass == .regular && size.width > size.height ? .spread : .single
    }

    /// The gap between facing pages: the fold's whole frame when there is one.
    private var spine: CGRect {
        if fold.isVertical, let frame = fold.frame { return frame }
        return CGRect(x: size.width / 2 - 16, y: 0, width: 32, height: size.height)
    }

    /// The region of the first page. In a spread both pages get the narrower region's size.
    private var region: CGSize {
        switch mode {
        case .spread: CGSize(width: min(spine.minX, size.width - spine.maxX), height: size.height)
        case .tabletop: CGSize(width: size.width, height: fold.frame?.minY ?? size.height)
        case .single: size
        }
    }

    private var pageSize: CGSize {
        CGSize(width: max(region.width - 2 * margin, 0), height: max(region.height - 2 * margin, 0))
    }

    /// The first page on screen. A spread starts on an even page so pages never swap sides.
    private var firstPage: Int {
        let page = breaks.page(containing: offset)
        return mode == .spread ? page - page % 2 : page
    }

    private var isAtEnd: Bool { firstPage + (mode == .spread ? 2 : 1) >= breaks.ranges.count }

    var body: some View {
        let stack = mode == .tabletop ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
        stack {
            // The first page is the same view in every mode, so it keeps its identity.
            page(firstPage)
                .frame(width: mode == .spread ? spine.minX : size.width,
                       height: mode == .tabletop ? region.height : size.height)
            switch mode {
            case .spread:
                Color.clear.frame(width: spine.width)
                page(firstPage + 1).frame(width: size.width - spine.maxX)
            case .tabletop:
                Color.clear.frame(height: fold.frame?.height ?? 0)
                HStack { turnButtons }                     // the stable base: big page turns
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .controlSize(.extraLarge)
                    .padding(.horizontal, 32)
                    .frame(maxHeight: .infinity)
            case .single:
                EmptyView()
            }
        }
        // minWidth and minHeight 0: the frame takes the offered size, not its content's,
        // so the measured size can't feed back into the page widths.
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .onFoldChange { fold = $0 }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .task(id: PaginationKey(chapter: chapter.id, page: pageSize, type: typeSize)) {
            // New size, new text size or new chapter: paginate again. The offset stays.
            // A fold or rotation sends many sizes in a row; wait until they settle.
            if !breaks.ranges.isEmpty { try? await Task.sleep(for: .milliseconds(200)) }
            guard !Task.isCancelled else { return }
            text = Paginator.styledText(chapter.text, size: typeSize)
            breaks = Paginator.pageBreaks(for: text, pageSize: pageSize)
        }
        // VoiceOver: a three-finger swipe turns the page.
        .accessibilityScrollAction { edge in turn(by: edge == .trailing || edge == .bottom ? 1 : -1) }
        .toolbar {
            if mode != .tabletop {                         // system bars stay off the fold
                ToolbarItemGroup(placement: .bottomBar) { turnButtons }
            }
        }
    }

    @ViewBuilder private var turnButtons: some View {
        Button("Previous Page", systemImage: "chevron.backward") { turn(by: -1) }
            .disabled(firstPage == 0)
        Spacer()
        Button("Next Page", systemImage: "chevron.forward") { turn(by: 1) }
            .disabled(isAtEnd)
    }

    private func page(_ index: Int) -> some View {
        let range = breaks.ranges.indices.contains(index) ? breaks.ranges[index] : nil
        return PageTextView(text: range.map { text.attributedSubstring(from: $0) } ?? NSAttributedString(),
                            onQuote: onQuote)
            .frame(width: pageSize.width, height: pageSize.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func turn(by direction: Int) {
        guard !breaks.ranges.isEmpty else { return }
        let target = firstPage + direction * (mode == .spread ? 2 : 1)
        offset = breaks.ranges[min(max(target, 0), breaks.ranges.count - 1)].location
    }

    private struct PaginationKey: Equatable {
        let chapter: String
        let page: CGSize
        let type: DynamicTypeSize
    }
}
```

## How it decides

| Fold in the reader | Mode | First page region | Second region |
|---|---|---|---|
| None, compact width or taller than wide | single | the whole reader | none |
| None, regular width and wider than tall (iPad, Mac) | spread | left of a 32 pt gutter | right of it |
| Top to bottom, active or not (open wide, book) | spread | leading side of the fold frame | trailing side |
| Side to side, inactive (open, flat, held tall) | single | the whole reader | none |
| Side to side, active (tabletop) | tabletop | above the fold frame | page turns below it |

## What we measured

iOS 27.1 iPhone Duo simulator, 20 Oct 2026, the reader inside a `NavigationStack` with a bottom toolbar, Large text, place at character 20,000. Raw log lines: [measurements.md](measurements.md).

| Pose | Reader | Page | Pages | On screen |
|---|---|---|---|---|
| Closed | 382 × 620 pt | 342 × 580 pt | 48 | page 22 (characters 19,515 to 20,417) |
| Open wide and book | 867 × 611 pt | 331.5 × 571 pt | 50 | pages 23 and 24 (from character 19,515) |
| Open, flat, tall | 669 × 787 pt | 629 × 747 pt | 21 | page 10 (characters 18,994 to 21,194) |
| Tabletop | 669 × 835 pt | 629 × 333.5 pt | 48 | page 22 (characters 19,620 to 20,575) |

- In the book screenshot the leading page ran from x = 62 to 393.5 and the trailing page from x = 515.5 to 847: both clear of the fold frame (455.5 to 495.5) and of the vertical bar (867 to 951).
- In tabletop the page's text view ran from y = 102 to 435.7 pt in the window (read by a UI test), above the fold at 455.5, and the page turn buttons sat in the bottom region.

## Pitfalls

- **A frame that grows to fit its content.** `.frame(maxWidth: .infinity)` alone takes the larger of the offer and the child. The pages' widths come from the measured size, so the size never shrank: 951 pt in an 867 pt space held wide, and 951 pt in a 669 pt tabletop window, with text cut off on both sides (*measured*). Add `minWidth: 0` and `minHeight: 0`, or measure with a `GeometryReader`.
- **Paginating on every intermediate size.** One rotation into tabletop sent six sizes in a row, and opening the phone seven (*measured*). Wait for the size to settle; `task(id:)` cancels the wait when a newer size arrives.
- **A tall page across an active fold.** Text lines landed inside the fold band in tabletop (*measured* before the fix). Fit the page to the region above the fold.
- **Splitting at `width / 2`.** The reader's middle is 22 pt left of the fold when the bar sits on the trailing side (*measured*).
- **Storing the page index.** Page 23 open is page 22 closed and page 10 held tall in the run above. Store the offset.
- **Rebuilding the page views.** Don't swap a spread view for a single-page view with `if`. Keep the first page as the same view so a fold doesn't drop its selection.
- **Paginating a whole book at once.** 558,000 characters took 1.1 to 3.1 s on the simulator, against 0.04 to 0.15 s for one chapter (*measured*). Paginate the chapter on screen.
- **Mixing TextKit 1 and 2.** Measure and draw with the same engine and the same `lineFragmentPadding` and insets.
