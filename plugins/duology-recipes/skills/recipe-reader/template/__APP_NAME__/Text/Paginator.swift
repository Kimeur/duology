#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Splits a chapter into pages of one size with TextKit 1.
///
/// It fills page-sized text containers until the text runs out, and records the
/// characters each one holds. The pages render with the same engine
/// (`PageTextView`: a TextKit 1 `UITextView` with the same padding), so a page never
/// overflows. On the Mac, AppKit has the same classes, so the model tests run it too.
enum Paginator {
    static func pageBreaks(for text: NSAttributedString, pageSize: CGSize) -> PageBreaks {
        guard text.length > 0, pageSize.width >= 44, pageSize.height >= 44 else { return PageBreaks() }
        let storage = NSTextStorage(attributedString: text)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        var ranges: [NSRange] = []
        while NSMaxRange(ranges.last ?? NSRange(location: 0, length: 0)) < text.length {
            let container = NSTextContainer(size: pageSize)
            container.lineFragmentPadding = 0          // PageTextView uses the same value
            layout.addTextContainer(container)
            let glyphs = layout.glyphRange(for: container)
            let characters = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            guard characters.length > 0 else { break } // not even one line fits
            ranges.append(characters)
        }
        return PageBreaks(ranges: ranges)
    }
}
