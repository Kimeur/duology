# Notes beside the page

A document on the leading side of the fold and the reader's notes on the trailing side, the way people read with a notebook open next to the book. Closed, held tall or in tabletop there is no room, so the notes open in a sheet. Needs `FoldGeometry` ([fold-geometry.md](fold-geometry.md)) and `PagedReader` ([paged-reader.md](paged-reader.md)).

## Why this layout

- The notes take the facing page's place. The reader then shows one page in the leading region, and every page turn moves one page.
- Trailing is where the system puts alerts in book pose, because that is where they sit once the phone closes ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=249)). Notes there stay near the controls the person reaches for.
- It is a supporting pane: the notes only make sense next to the document ([`duo-patterns` supporting pane](https://github.com/Kimeur/duology/blob/main/plugins/duology-design/skills/duo-patterns/references/supporting-pane.md)). We don't use `ArrangementView` here: with `.split.axes(.horizontal)` it shows only the primary view in a frame taller than wide, such as the closed phone, and no API tells you the secondary is hidden, so you can't offer the sheet at the right moment (*measured* in `duo-patterns`).
- An `inspector` would also work, but its column width doesn't follow the fold.

## Code

```swift
import Observation
import SwiftUI

// requires: FoldGeometry (references/fold-geometry.md)
// requires: Chapter, PagedReader (references/paged-reader.md)

/// Reading state for one window. Lives above every layout switch, so a fold
/// never loses the place, the notes or whether the notes are open.
@MainActor @Observable
final class ReadingSession {
    var offset = 0
    var notes = ""
    var showsNotes = false

    func quote(_ passage: String) {
        notes += (notes.isEmpty ? "" : "\n\n") + "\u{201C}\(passage)\u{201D}"
        showsNotes = true
    }
}

/// The page on the leading side of the fold and the notes on the trailing side.
/// Closed, or with no room, the notes open in a sheet instead.
@available(iOS 27.1, *)
struct ReaderWithNotes: View {
    let chapter: Chapter
    @Bindable var session: ReadingSession

    @State private var fold = FoldGeometry()
    @State private var size = CGSize.zero
    @Environment(\.horizontalSizeClass) private var widthClass

    /// Room for notes beside the page: a top-to-bottom fold, or a wide regular-width view.
    private var hasRoom: Bool {
        if fold.frame != nil { return fold.isVertical }
        return widthClass == .regular && size.width > size.height
    }

    private var showsSide: Bool { session.showsNotes && hasRoom }

    /// The gap: the fold's whole frame when there is one, else a centred gutter.
    private var gap: CGRect {
        if fold.isVertical, let frame = fold.frame { return frame }
        return CGRect(x: size.width / 2 - 16, y: 0, width: 32, height: size.height)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Same reader view whether the notes show or not: it keeps its identity.
            PagedReader(chapter: chapter, offset: $session.offset, onQuote: session.quote)
                .frame(width: showsSide ? gap.minX : size.width)
            if showsSide {
                Color.clear.frame(width: gap.width)
                NotesEditor(text: $session.notes)
                    .frame(width: size.width - gap.maxX)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .leading)
        .onFoldChange { fold = $0 }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .sheet(isPresented: notesSheet) {
            NavigationStack {
                NotesEditor(text: $session.notes)
                    .navigationTitle("Notes")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { session.showsNotes = false }
                        }
                    }
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Notes", systemImage: "note.text") { session.showsNotes.toggle() }
            }
        }
    }

    /// Shown only while there is no room beside the page. Opening the phone
    /// dismisses the sheet and the notes move beside the page; closing does the reverse.
    private var notesSheet: Binding<Bool> {
        Binding {
            session.showsNotes && !hasRoom
        } set: { isPresented in
            // A swipe down closes the notes. A dismissal caused by opening the phone doesn't.
            if !isPresented && !hasRoom { session.showsNotes = false }
        }
    }
}

/// No navigationTitle here: beside the page it would retitle the reader's stack.
struct NotesEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(.background.secondary, in: .rect(cornerRadius: 16))
            .padding()
            .accessibilityLabel("Notes")
    }
}
```

## What we measured

iOS 27.1 iPhone Duo simulator, 20 Oct 2026, launched closed with the notes open:

- Closed: the notes showed as a sheet over the page, with Done.
- Opened: the sheet went away on its own, and the notes appeared on the trailing side, starting after the fold. The reader shrank to the leading region: 455.5 × 611 pt, one page of 415.5 × 571 pt, still holding the place.
- Closed again: the reader went back to 382 × 620 pt with one page, and the notes sheet came back with Done.
- In an earlier version with `.navigationTitle` on the editor itself, the pane retitled the whole reader "Notes" with a large title, and the reader lost 58 pt of height (455.5 × 553 pt). Put the title on the sheet's `NavigationStack` only.

## Rules

1. One model for the offset, the notes and `showsNotes`, created once per window above the layout.
2. The sheet's binding reads "notes wanted and no room". Its setter clears `showsNotes` only when there is still no room, so a dismissal caused by opening the phone keeps the notes open beside the page.
3. Keep the reader the same view whether the notes show or not, so it keeps its identity.
4. The sheet and the pane hold two different editors, so keyboard focus doesn't follow the notes. The text does. Where the keyboard appears in book pose and tabletop is unverified: check that the caret stays visible.
5. "Add to Notes" from a page selection appends a quote and opens the notes, in whichever form fits the pose.
