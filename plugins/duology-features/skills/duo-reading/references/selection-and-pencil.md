# Selection, drag and Apple Pencil

## Selection stays inside one text view

A two-page spread is two text views, one per region. A selection starts and ends inside one of them, so it can't run from the leading page across the fold to the trailing page. Design for that instead of fighting it.

| Need | Do this |
|---|---|
| Copy, look up, translate, share a phrase | The system edit menu of the page's `UITextView`. It works on either page in every pose. |
| Keep a quote | **Add to Notes** in the edit menu (`PageTextView` in [paged-reader.md](paged-reader.md)). It appends the selection to the notes and opens them. |
| Move a quote with a finger | Drag the selection to the notes. |
| Highlight a long passage that crosses pages | A scroll layout of the chapter in one text view, which may cross the fold because it scrolls. Store the highlight as a character range, so it shows in either layout. |

### SwiftUI `Text`

In iOS 27, `textSelection(.enabled)` on a `Text` shows the system selection handles and selects a range. In iOS 26 and earlier, a touch and hold offered a menu that acted on the whole text ([`textSelection(_:)`](https://developer.apple.com/documentation/swiftui/view/textselection(_:))). Apple's page also says the modifier on a container makes each text view in it selectable; it says nothing about one selection spanning two `Text` views. Treat a selection as one view's, and test what your build does in book pose. (unverified across two `Text` views)

`TextSelection` and `AttributedTextSelection` belong to editable text: `TextField` and `TextEditor` (iOS 18 and iOS 26). `Text` has no binding that reports what is selected, so "Add to Notes" needs the `UITextView` page or a `TextEditor`.

### UITextView

- `PageTextView` is not editable but is selectable, so the full edit menu works.
- `textView(_:editMenuForTextInRanges:suggestedActions:)` (iOS 26) adds actions to that menu ([doc](https://developer.apple.com/documentation/uikit/uitextviewdelegate/textview(_:editmenufortextinranges:suggestedactions:))). Return `nil` to keep the system menu unchanged. Put your own action first: the menu shows a few items, then pages (*measured*, [paged-reader.md](paged-reader.md)).
- *Measured* on the iPhone Duo simulator: `UIDragInteraction.isEnabledByDefault` was `true`, and so was `textDragInteraction?.isEnabled` on a new `UITextView`. Apple documents the default as depending on the device ([doc](https://developer.apple.com/documentation/uikit/uidraginteraction/isenabledbydefault)), so set it yourself. Whether a SwiftUI `TextEditor` accepts the drop on a device is unverified.

## Apple Pencil: coming, not here yet

- Apple's announcement says iPhone Duo will support Apple Pencil with USB-C later in 2026, to take notes, sketch and mark up documents on either display ([Newsroom](https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/)). On 20 Oct 2026 we found no Pencil API new in iOS 27.1, and nothing about iPhone Duo, in the PencilKit and UIKit pencil headers of the iOS 27.1 SDK. (unverified which Pencil features iPhone Duo will support)
- On iPad, Apple Pencil (USB-C) supports tilt and, on some models, hover. It has no pressure sensitivity, double tap, squeeze, barrel roll or haptics ([Apple Pencil](https://www.apple.com/apple-pencil/)). Don't build features that need them.
- Every feature must work with a finger. PencilKit's `drawingPolicy = .anyInput` lets fingers draw ([`PKCanvasView`](https://developer.apple.com/documentation/pencilkit/pkcanvasview)).

### Where ink may go

- **Fixed pages** (PDF pages, images, slides): ink is fine. Store each page's `PKDrawing` with that page, in the page's own coordinates. When the page is shown at another scale after a fold, scale the strokes with `PKDrawing.transformed(using:)`. (unverified on iPhone Duo)
- **Reflowing text**: no ink. Every fold, rotation and text size moves the words, so a stroke would end up over the wrong line. Store highlights and comments as character ranges.
- **Across the fold**: one canvas per page. A stroke dragged over the fold lands in the fold band, which Apple asks you to keep free of interactive content when the phone is partly folded ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=568)).

```swift
import PencilKit
import SwiftUI

/// Ink over a fixed page, such as a PDF page or an image. Fingers draw today.
struct MarkupCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput           // finger and, once supported, Apple Pencil
        canvas.tool = PKInkingTool(.marker, color: .systemYellow, width: 12)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(drawing: $drawing) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let drawing: Binding<PKDrawing>
        init(drawing: Binding<PKDrawing>) { self.drawing = drawing }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing.wrappedValue = canvasView.drawing   // save it with the page it belongs to
        }
    }
}
```

- `canvasViewDrawingDidChange(_:)` saves after each stroke. Keep the drawing in your model, keyed by page, never in the view: a fold can rebuild the view.
- The system tool picker (`PKToolPicker`) needs a first responder canvas. Where it appears on iPhone Duo, and whether it avoids the fold, is unverified.
