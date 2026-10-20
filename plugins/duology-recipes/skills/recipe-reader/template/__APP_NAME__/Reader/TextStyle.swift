import SwiftUI
import UIKit

/// How a chapter looks: a serif body at the reader's Dynamic Type size, and a larger
/// title. The paginator and the page views both use this text, so a page break
/// always falls where the page ends.
enum TextStyle {
    static func attributed(_ chapter: ChapterText, size: DynamicTypeSize) -> NSAttributedString {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        let bodyFont = font(.body, traits: traits)
        let titleFont = font(.title1, traits: traits, bold: true)

        let body = NSMutableParagraphStyle()
        body.lineHeightMultiple = 1.12
        body.paragraphSpacing = (bodyFont.pointSize * 0.6).rounded()
        body.hyphenationFactor = 0.6          // fewer ragged lines on a narrow page

        let title = NSMutableParagraphStyle()
        title.paragraphSpacing = (titleFont.pointSize * 0.8).rounded()

        let text = NSMutableAttributedString(string: chapter.string, attributes: [
            .font: bodyFont,
            .foregroundColor: UIColor.label,  // follows light and dark mode
            .paragraphStyle: body,
        ])
        text.addAttributes([.font: titleFont, .paragraphStyle: title], range: chapter.titleRange)
        return text
    }

    /// The system serif (New York) for a text style, scaled for `traits`.
    private static func font(_ style: UIFont.TextStyle, traits: UITraitCollection, bold: Bool = false) -> UIFont {
        var descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style, compatibleWith: traits)
        if let serif = descriptor.withDesign(.serif) { descriptor = serif }
        if bold, let heavier = descriptor.withSymbolicTraits(.traitBold) { descriptor = heavier }
        return UIFont(descriptor: descriptor, size: 0)
    }
}

extension DynamicTypeSize {
    /// This size moved by `step` sizes, kept inside the 12 sizes SwiftUI has.
    func moved(by step: Int) -> DynamicTypeSize {
        let sizes = DynamicTypeSize.allCases
        let current = sizes.firstIndex(of: self) ?? 3
        return sizes[TextSizeStep.index(system: current, step: step, count: sizes.count)]
    }

    /// The step that `moved(by:)` really applies from this size.
    func clampedStep(_ step: Int) -> Int {
        let sizes = DynamicTypeSize.allCases
        return TextSizeStep.clamped(step, system: sizes.firstIndex(of: self) ?? 3, count: sizes.count)
    }
}
