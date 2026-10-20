import SwiftUI
import UIKit

/// One page: the running head, the text and the page number. The text frame is
/// exactly the size the chapter was paginated for, so nothing spills over.
struct PageView: View {
    let text: NSAttributedString
    let runningHead: String
    /// "12", or empty for a blank page at the end of a chapter.
    let number: String
    let pageSize: CGSize
    let insets: PageInsets

    var body: some View {
        VStack(spacing: 0) {
            Text(runningHead)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: pageSize.width, height: insets.top)
                .accessibilityHidden(true)
            PageTextView(text: text)
                .frame(width: pageSize.width, height: pageSize.height)
            Text(number)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: pageSize.width, height: insets.bottom)
                .accessibilityHidden(true)
        }
        // The head and number are page furniture: they stay small at any text size.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(number.isEmpty ? "Blank page" : "Page \(number)")
    }
}

/// The text of one page, laid out by TextKit 1 like the paginator, so a page never
/// overflows. Selectable, not editable, never scrolls.
struct PageTextView: UIViewRepresentable {
    let text: NSAttributedString

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView(usingTextLayoutManager: false)   // TextKit 1, same engine as Paginator
        view.isEditable = false
        view.isScrollEnabled = false
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0              // same as Paginator
        view.backgroundColor = .clear
        view.adjustsFontForContentSizeCategory = false          // the text already has the reader's size
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.attributedText != text { view.attributedText = text }
    }

    /// Take exactly the size SwiftUI offers: the size the text was paginated for.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }
}
