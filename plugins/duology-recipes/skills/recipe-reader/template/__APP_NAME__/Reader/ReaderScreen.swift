import SwiftUI

/// The reader. One page on the closed phone; two facing pages, split at the fold,
/// when the phone is open and held wide or folded like a book; in tabletop, the page
/// above the fold and the page turns below it.
///
/// The place is a character offset in `LibraryStore`. A fold, a rotation or a new text
/// size changes the page breaks, never the offset: the reader paginates again and
/// shows the page that holds it.
struct ReaderScreen: View {
    let book: Book
    let store: LibraryStore

    @State private var fold = FoldGeometry()
    @State private var size = CGSize.zero
    @State private var breaks = PageBreaks()
    @State private var styled = NSAttributedString()
    /// What `breaks` were made for. Nil until the first pagination.
    @State private var paginated: PaginationKey?
    @Environment(\.dynamicTypeSize) private var systemTypeSize
    @Environment(\.horizontalSizeClass) private var widthClass

    private var position: ReadingPosition { store.position(of: book) }
    private var chapter: Chapter { book.chapters[position.chapter] }
    private var typeSize: DynamicTypeSize { systemTypeSize.moved(by: store.textStep) }

    private var layout: ReaderLayout {
        ReaderLayout(size: size, fold: fold, prefersSpread: widthClass == .regular)
    }

    private var key: PaginationKey {
        PaginationKey(chapter: position.chapter, page: layout.pageSize, type: typeSize)
    }

    /// The breaks belong to the chapter on screen. Right after a fold they may still be
    /// for the old page size, for a moment; never for another chapter.
    private var hasPages: Bool { paginated?.chapter == position.chapter && !breaks.isEmpty }

    private var firstPage: Int {
        breaks.firstPage(showing: position.offset, perSpread: layout.perSpread)
    }

    var body: some View {
        let layout = self.layout
        ZStack(alignment: .topLeading) {
            Color.clear
            // The first page is the same view in every pose, so a fold never rebuilds it.
            page(slot: 0, in: layout)
            if layout.mode == .spread {
                page(slot: 1, in: layout)
            }
            if let controls = layout.controls {
                tabletopControls
                    .frame(width: controls.width, height: controls.height)
                    .position(x: controls.midX, y: controls.midY)
            }
        }
        // minWidth and minHeight 0: the reader takes the size it is offered, never
        // its pages' size, so its measured size can't feed back into the page widths.
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .contentShape(.rect)
        .simultaneousGesture(swipe)
        .onFoldChange { fold = $0 }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .task(id: key) { await paginate(key) }
        // VoiceOver: a three-finger swipe turns the page.
        .accessibilityScrollAction { edge in turn(forward: edge == .trailing || edge == .bottom) }
        .background(Color(.systemBackground))
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // In tabletop the same controls move below the fold, out of the bars.
            if layout.mode != .tabletop {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    contentsMenu
                    textSizeMenu
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    previousButton
                    Spacer()
                    nextButton
                }
            }
        }
        .testMarker("reader.state", value: testSummary)
    }

    // MARK: Pages

    private func page(slot: Int, in layout: ReaderLayout) -> some View {
        let region = layout.regions[min(slot, layout.regions.count - 1)]
        let index = firstPage + slot
        let range = hasPages && breaks.ranges.indices.contains(index) ? breaks.ranges[index] : nil
        return PageView(text: range.map { styled.attributedSubstring(from: $0) } ?? NSAttributedString(),
                        runningHead: slot == 0 && layout.mode == .spread ? book.title : chapter.title,
                        number: range == nil ? "" : "\(index + 1)",
                        pageSize: layout.pageSize,
                        insets: layout.insets)
            .frame(width: region.width, height: region.height)
            .position(x: region.midX, y: region.midY)
            .accessibilityIdentifier("reader.page.\(slot)")
    }

    /// Lays the chapter out again for a new page size, text size or chapter. The place stays.
    private func paginate(_ key: PaginationKey) async {
        // A fold or rotation sends many sizes in a row: wait for them to settle. A new
        // chapter or text size paginates at once, so old text never shows.
        if let paginated, paginated.chapter == key.chapter, paginated.type == key.type {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
        }
        guard key.page != .zero else { return }
        let text = TextStyle.attributed(store.text(of: book, chapter: key.chapter), size: key.type)
        styled = text
        breaks = Paginator.pageBreaks(for: text, pageSize: key.page)
        paginated = key
    }

    // MARK: Turning pages

    private func turn(forward: Bool) {
        guard hasPages else { return }
        let turn = breaks.turn(forward: forward, from: position.offset, perSpread: layout.perSpread,
                               chapter: position.chapter, chapterCount: book.chapters.count)
        store.apply(turn, in: book)
    }

    private var canGoBack: Bool { position.chapter > 0 || firstPage > 0 }
    private var canGoForward: Bool {
        position.chapter + 1 < book.chapters.count || !breaks.isAtEnd(from: firstPage, perSpread: layout.perSpread)
    }

    /// A horizontal swipe turns the page: right to left goes forward.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24).onEnded { value in
            let dx = value.translation.width
            guard abs(dx) > 60, abs(dx) > abs(value.translation.height) * 1.5 else { return }
            turn(forward: dx < 0)
        }
    }

    // MARK: Controls (the same ones in the bars and in tabletop)

    private var previousButton: some View {
        Button("Previous Page", systemImage: "chevron.backward") { turn(forward: false) }
            .disabled(!canGoBack)
            .accessibilityIdentifier("reader.previous")
    }

    private var nextButton: some View {
        Button("Next Page", systemImage: "chevron.forward") { turn(forward: true) }
            .disabled(!canGoForward)
            .accessibilityIdentifier("reader.next")
    }

    private var contentsMenu: some View {
        Menu {
            Picker("Chapter", selection: Binding(
                get: { position.chapter },
                set: { store.move(book, to: ReadingPosition(chapter: $0, offset: 0)) }
            )) {
                ForEach(book.chapters.indices, id: \.self) { index in
                    Text(book.chapters[index].title).tag(index)
                }
            }
        } label: {
            Label("Contents", systemImage: "list.bullet")
        }
        .accessibilityIdentifier("reader.contents")
    }

    private var textSizeMenu: some View {
        Menu {
            Button("Larger Text", systemImage: "textformat.size.larger") {
                store.textStep = systemTypeSize.clampedStep(store.textStep + 1)
            }
            .disabled(typeSize == DynamicTypeSize.allCases.last)
            Button("Smaller Text", systemImage: "textformat.size.smaller") {
                store.textStep = systemTypeSize.clampedStep(store.textStep - 1)
            }
            .disabled(typeSize == DynamicTypeSize.allCases.first)
            Button("Default Size", systemImage: "arrow.counterclockwise") { store.textStep = 0 }
                .disabled(store.textStep == 0)
        } label: {
            Label("Text Size", systemImage: "textformat.size")
        }
        .accessibilityIdentifier("reader.textSize")
    }

    /// Tabletop: on the stable half below the fold, big page turns and the same menus.
    private var tabletopControls: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text(chapter.title)
                    .font(.headline)
                Text(pageStatus)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            HStack(spacing: 20) {
                previousButton
                contentsMenu
                textSizeMenu
                nextButton
            }
            .labelStyle(.iconOnly)
            .font(.title2)
            .buttonStyle(.glass)
            .controlSize(.extraLarge)
        }
        .padding(24)
    }

    private var pageStatus: String {
        guard hasPages else { return " " }
        return "Page \(firstPage + 1) of \(breaks.count)"
    }

    // MARK: Test marker

    /// What UI tests read from `reader.state`. Every field ends with "|".
    private var testSummary: String {
        let shown = hasPages ? breaks.shown(from: firstPage, perSpread: layout.perSpread) : nil
        return [
            "book=\(book.id)",
            "chapter=\(position.chapter)",
            "offset=\(position.offset)",
            "first=\(firstPage)",
            "pages=\(hasPages ? breaks.count : 0)",
            "mode=\(layout.mode.rawValue)",
            "shown=\(shown.map { "\($0.location)-\(NSMaxRange($0))" } ?? "none")",
            "step=\(store.textStep)",
            "ready=\(paginated == key ? 1 : 0)",
        ].map { $0 + "|" }.joined()
    }
}

/// What a set of page breaks was made for.
private struct PaginationKey: Equatable {
    let chapter: Int
    let page: CGSize
    let type: DynamicTypeSize
}
