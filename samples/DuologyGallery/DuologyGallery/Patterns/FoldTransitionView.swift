import SwiftUI

/// Fold transition: a field guide that keeps your place.
///
/// What stays put when the phone folds, unfolds or rotates:
/// - The reading column and its tools. On the inner display the article sits in
///   the region beside the fold, about as wide as the outer display, so lines
///   barely reflow and the floating tools keep their place under the text.
/// - The scroll position: the paragraph at the top, kept as an ID and put back
///   with `ScrollPosition` whenever the column changes width.
/// - The selected paragraph, the highlights, the text size and the bookmark,
///   all in one model above the layout.
///
/// One custom layout holds the article in every pose, so SwiftUI never rebuilds
/// it. The contents list is a sheet on the outer display and a pane beside the
/// fold on the inner display. It splits at the fold line even when the phone
/// lies flat, so folding it later moves nothing.
///
/// Skills: `duo-transitions` and `duo-continuity`.
struct FoldTransitionView: View {
    @State private var model = ReadingModel(guide: .lowTide, selection: LaunchOptions.selection)
    @State private var fold = FoldGeometry()
    @State private var size = CGSize.zero
    @State private var showsContentsSheet = false
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The contents pane shows whenever the layout has a region for it.
    private var showsContents: Bool {
        ReadingLayout.regions(in: CGRect(origin: .zero, size: size), fold: fold, widthClass: widthClass) != nil
    }

    /// The pane sits to the leading side: a fold top to bottom, or a sidebar with no fold.
    private var articleBesidePane: Bool {
        showsContents && (fold.frame == nil || fold.isVertical)
    }

    var body: some View {
        NavigationStack {
            ReadingLayout(fold: fold, widthClass: widthClass) {
                if showsContents {
                    ContentsPane(model: model)
                        .transition(.opacity)
                }
                // Always the last child, so it keeps its identity when the pane comes and goes.
                // Beside a pane, its leading edge is inside the window, where the
                // system's container margin is zero, so it gets a margin of its own.
                ArticleColumn(model: model, leadingInset: articleBesidePane ? DuoSpace.x5 : 0)
            }
            // Read the fold on the layout itself, so its frame is in the layout's space.
            .onFoldChange { fold = $0 }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            // Keyed on discrete values, never on the raw size. Nil under Reduce Motion.
            .animation(reduceMotion ? nil : .smooth(duration: 0.3),
                       value: ReadingLayoutKey(fold: fold, showsContents: showsContents))
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Field Guide")
            .navigationBarTitleDisplayMode(.inline)
            .galleryCloseButton()
            .toolbar {
                // Shown exactly when the pane is hidden: the same content, one tap away.
                if !showsContents {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Contents", systemImage: "list.bullet") { showsContentsSheet = true }
                    }
                }
            }
            .sheet(isPresented: $showsContentsSheet) {
                NavigationStack {
                    ContentsPane(model: model) { showsContentsSheet = false }
                        .navigationTitle("Contents")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close", systemImage: "xmark", role: .close) { showsContentsSheet = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
            .onChange(of: showsContents) { _, isShown in
                // Unfolded with the sheet open: the pane takes over.
                if isShown { showsContentsSheet = false }
            }
        }
    }
}

nonisolated private struct ReadingLayoutKey: Equatable {
    var fold: FoldGeometry
    var showsContents: Bool
}

// MARK: - Layout

/// The contents pane and the article. With a fold in the view (flat or folded),
/// the split sits on the fold line: contents leading or on top, the article
/// trailing or below. With no fold (the outer display) the article fills the view.
/// One layout type in every pose, so the article view is never rebuilt.
private struct ReadingLayout: Layout {
    var fold: FoldGeometry
    var widthClass: UserInterfaceSizeClass?

    /// Contents width when no fold crosses the view but there is room for a sidebar.
    static let sidebarWidth: CGFloat = 320

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let article = subviews.last else { return }
        let local = CGRect(origin: .zero, size: bounds.size)
        if subviews.count == 2, let (contents, reading) = Self.regions(in: local, fold: fold, widthClass: widthClass) {
            subviews[0].place(at: CGPoint(x: bounds.minX + contents.minX, y: bounds.minY + contents.minY),
                              proposal: ProposedViewSize(contents.size))
            article.place(at: CGPoint(x: bounds.minX + reading.minX, y: bounds.minY + reading.minY),
                          proposal: ProposedViewSize(reading.size))
        } else {
            // For one frame after a fold the pane can still be here with no region: give it no room.
            if subviews.count == 2 {
                subviews[0].place(at: bounds.origin, proposal: .zero)
            }
            article.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }

    /// The contents region and the article region in a view of `bounds`
    /// (origin zero), or nil for the article alone. A pure function.
    static func regions(in bounds: CGRect, fold: FoldGeometry,
                        widthClass: UserInterfaceSizeClass?) -> (CGRect, CGRect)? {
        if let f = fold.frame {
            // Active or flat: split on the fold line, so folding moves nothing.
            // Use the fold only when it crosses the middle half of the view.
            if fold.isVertical, f.midX > bounds.width / 4, f.midX < bounds.width * 3 / 4 {
                return (CGRect(x: 0, y: 0, width: f.minX, height: bounds.height),
                        CGRect(x: f.maxX, y: 0, width: bounds.width - f.maxX, height: bounds.height))
            }
            if !fold.isVertical, f.midY > bounds.height / 4, f.midY < bounds.height * 3 / 4 {
                return (CGRect(x: 0, y: 0, width: bounds.width, height: f.minY),
                        CGRect(x: 0, y: f.maxY, width: bounds.width, height: bounds.height - f.maxY))
            }
            return nil
        }
        // No fold in the view: a sidebar when the width is regular and two columns fit.
        guard widthClass == .regular, bounds.width >= sidebarWidth * 2.2 else { return nil }
        return (CGRect(x: 0, y: 0, width: sidebarWidth, height: bounds.height),
                CGRect(x: sidebarWidth, y: 0, width: bounds.width - sidebarWidth, height: bounds.height))
    }
}

// MARK: - Model

/// Everything the reader would hate to lose. It lives above the layout, so a
/// fold, an unfold or a rotation keeps all of it.
@Observable
final class ReadingModel {
    let guide: FieldGuide
    /// Where the article is, as a block ID. SwiftUI keeps a view with that ID in
    /// place when the scroll view changes size. A point offset gets no such help.
    var scroll: ScrollPosition
    /// Blocks at least half on screen, from the scroll view.
    var visible: [Int] = []
    var selected: Int?
    var highlights: Set<Int>
    var bookmark: Int?
    /// The reader's own text size step, on top of the system Dynamic Type size.
    var textStep = 2
    /// The block the reader is on. Set when a scroll comes to rest or a jump
    /// lands, never by a resize. The article scrolls back to it after every
    /// width change (open, close, fold, rotate): on the iOS 27.1 simulator the
    /// scroll view alone lost the paragraph when the column got narrower
    /// (measured on unfold and when launched open).
    var anchorID = 0

    static let textScales: [CGFloat] = [0.84, 0.92, 1, 1.1, 1.22, 1.36]

    init(guide: FieldGuide, selection: Int?) {
        self.guide = guide
        let valid = selection.flatMap { guide.block($0) == nil ? nil : $0 }
        selected = valid
        highlights = guide.sampleHighlights
        bookmark = guide.sampleBookmark
        scroll = ScrollPosition(idType: Int.self)
        // With `-select`, start at the section that holds the paragraph.
        if let valid, let heading = guide.headingID(containing: valid) {
            anchorID = heading
            visible = [heading]
        }
    }

    /// A scroll the reader made came to rest: remember where they are.
    func scrollDidSettle() {
        anchorID = topID
    }

    /// The topmost block on screen.
    var topID: Int { visible.min() ?? 0 }

    var currentSection: FieldGuide.Section? {
        guide.sections.last { $0.headingID <= topID }
    }

    var textScale: CGFloat { Self.textScales[textStep] }

    var isSelectionHighlighted: Bool {
        selected.map(highlights.contains) ?? false
    }

    var isBookmarkOnScreen: Bool {
        bookmark.map(visible.contains) ?? false
    }

    func toggleSelection(_ id: Int) {
        selected = selected == id ? nil : id
    }

    func toggleHighlight() {
        guard let selected else { return }
        if highlights.contains(selected) {
            highlights.remove(selected)
        } else {
            highlights.insert(selected)
        }
    }

    func toggleBookmark() {
        bookmark = isBookmarkOnScreen ? nil : topID
    }

    func jump(to id: Int) {
        anchorID = id
        withAnimation(.smooth) { scroll.scrollTo(id: id, anchor: .top) }
    }

    /// Minutes of reading left from the top of the screen, at 200 words a minute.
    var minutesLeft: Int {
        let words = guide.blocks.filter { $0.id >= topID }.reduce(0) { $0 + $1.wordCount }
        return max(1, Int((Double(words) / 200).rounded(.up)))
    }

    var progress: Double {
        guard let last = guide.blocks.last?.id, last > 0 else { return 0 }
        return Double(topID) / Double(last)
    }
}

// MARK: - Article

private struct ArticleColumn: View {
    @Bindable var model: ReadingModel
    var leadingInset: CGFloat = 0
    @State private var columnWidth = 0
    @ScaledMetric(relativeTo: .body) private var bodySize = 19.0

    var body: some View {
        // The reader gives a scroll command that always runs. A ScrollPosition
        // that already names the paragraph does nothing when asked again.
        ScrollViewReader { proxy in
            ScrollView {
                // A plain stack: the guide is short, and every block has its real
                // height, so a position by ID lands exactly where it should.
                VStack(alignment: .leading, spacing: 16) {
                    ArticleHeader(guide: model.guide)
                        .id(0)
                    ForEach(model.guide.blocks) { block in
                        BlockView(block: block,
                                  bodySize: bodySize * model.textScale,
                                  isSelected: model.selected == block.id,
                                  isHighlighted: model.highlights.contains(block.id),
                                  isBookmarked: model.bookmark == block.id) {
                            model.toggleSelection(block.id)
                        }
                        .id(block.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.leading, leadingInset)
                .containerMargins(.horizontal)
                .padding(.top, 8)
            }
            .scrollPosition($model.scroll, anchor: .top)
            .onGeometryChange(for: Int.self) { Int($0.size.width.rounded()) } action: { width in
                columnWidth = width
                proxy.scrollTo(model.anchorID, anchor: .top)
            }
            // The width arrives in steps while the window resizes. Once it has
            // settled, put the reader's paragraph back at the top again.
            .task(id: columnWidth) {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                proxy.scrollTo(model.anchorID, anchor: .top)
            }
            .onScrollPhaseChange { oldPhase, newPhase in
                // Only a scroll the reader made moves the anchor. A resize or a jump does not.
                if newPhase == .idle, oldPhase == .interacting || oldPhase == .decelerating {
                    model.scrollDidSettle()
                }
            }
            .scrollEdgeEffectStyle(.hard, for: [.top, .bottom])
            .onScrollTargetVisibilityChange(idType: Int.self) { ids in
                if !ids.isEmpty { model.visible = ids }
            }
            // Bars of our own with the system's scroll edge effect (iOS 26): text
            // fades under them, and the scroll view makes room for them.
            .safeAreaBar(edge: .top, spacing: 0) {
                ReadingProgress(model: model, leadingInset: leadingInset)
            }
            .safeAreaBar(edge: .bottom) {
                ReadingTools(model: model)
            }
            .background { Color(.systemBackground).ignoresSafeArea() }
        }
    }
}

private struct ArticleHeader: View {
    let guide: FieldGuide

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(guide.kicker)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(FieldGuide.tint)
            Text(guide.title)
                .font(.system(.largeTitle, design: .serif).weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("\(guide.author) · \(guide.readingMinutes) min read")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct BlockView: View {
    let block: FieldGuide.Block
    let bodySize: CGFloat
    let isSelected: Bool
    let isHighlighted: Bool
    let isBookmarked: Bool
    let onTap: () -> Void

    var body: some View {
        switch block.kind {
        case .heading(let symbol):
            Label {
                Text(block.text)
                    .font(.system(.title2, design: .serif).weight(.bold))
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(FieldGuide.tint)
            }
            .padding(.top, 12)
            .accessibilityAddTraits(.isHeader)
        case .paragraph:
            Text(block.text)
                .font(.system(size: bodySize, design: .serif))
                .lineSpacing(bodySize * 0.3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHighlighted ? Color.yellow.opacity(0.3)
                              : isSelected ? FieldGuide.tint.opacity(0.08) : .clear)
                }
                .overlay(alignment: .leading) {
                    if isSelected {
                        Capsule()
                            .fill(FieldGuide.tint)
                            .frame(width: 3)
                            .padding(.vertical, 4)
                            .offset(x: -6)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isBookmarked {
                        Image(systemName: "bookmark.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .offset(x: 4, y: -6)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, -10)
                .contentShape(.rect)
                .onTapGesture(perform: onTap)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                .accessibilityValue(isHighlighted ? "Highlighted" : "")
                .accessibilityHint("Selects the paragraph")
        }
    }
}

/// Where you are: a thin progress bar, the section and the time left.
private struct ReadingProgress: View {
    let model: ReadingModel
    var leadingInset: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.currentSection?.title ?? "Start of the guide")
                    .font(.footnote.weight(.semibold))
                Spacer()
                Text("\(model.minutesLeft) min left")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .contentTransition(.identity)
            ProgressView(value: model.progress)
                .tint(FieldGuide.tint)
                .accessibilityHidden(true)
        }
        .padding(.leading, leadingInset)
        .containerMargins(.horizontal)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

/// The reading tools. One group with one look, at the bottom centre of the
/// article in every pose. They move only because the article's region moves.
private struct ReadingTools: View {
    let model: ReadingModel

    var body: some View {
        HStack(spacing: 2) {
            Button("Smaller Text", systemImage: "textformat.size.smaller") { model.textStep -= 1 }
                .disabled(model.textStep == 0)
                .duoTouchTarget()
            Button("Larger Text", systemImage: "textformat.size.larger") { model.textStep += 1 }
                .disabled(model.textStep == ReadingModel.textScales.count - 1)
                .duoTouchTarget()
            Divider()
                .frame(height: 24)
                .padding(.horizontal, 6)
            Button(model.isSelectionHighlighted ? "Remove Highlight" : "Highlight", systemImage: "highlighter") {
                model.toggleHighlight()
            }
            .disabled(model.selected == nil)
            .foregroundStyle(model.isSelectionHighlighted ? Color.orange : Color.primary)
            .duoTouchTarget()
            Button(model.isBookmarkOnScreen ? "Remove Bookmark" : "Add Bookmark",
                   systemImage: model.isBookmarkOnScreen ? "bookmark.fill" : "bookmark") {
                model.toggleBookmark()
            }
            .foregroundStyle(model.isBookmarkOnScreen ? Color.red : Color.primary)
            .duoTouchTarget()
        }
        .labelStyle(.iconOnly)
        .font(.title3)
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.bottom, 16)
    }
}

// MARK: - Contents

/// Sections, highlights and the bookmark. A sheet when closed, a pane when open.
private struct ContentsPane: View {
    let model: ReadingModel
    var onPick: () -> Void = {}

    var body: some View {
        List {
            Section("Contents") {
                ForEach(model.guide.sections) { section in
                    let isCurrent = model.currentSection?.id == section.id
                    Button {
                        model.jump(to: section.headingID)
                        onPick()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: section.symbol)
                                .foregroundStyle(FieldGuide.tint)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.title)
                                    .foregroundStyle(.primary)
                                Text("\(model.guide.minutes(in: section)) min")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if isCurrent {
                                Text("Reading")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(FieldGuide.tint)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(isCurrent ? FieldGuide.tint.opacity(0.12) : nil)
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                }
            }

            Section("Highlights") {
                if model.highlights.isEmpty {
                    Text("Select a paragraph, then tap the highlighter.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.highlights.sorted(), id: \.self) { id in
                    Button {
                        model.jump(to: id)
                        onPick()
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Capsule()
                                .fill(Color.yellow)
                                .frame(width: 4)
                            Text(model.guide.block(id)?.text ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let bookmark = model.bookmark, let section = model.guide.sections.last(where: { $0.headingID <= bookmark }) {
                Section("Bookmark") {
                    Button {
                        model.jump(to: bookmark)
                        onPick()
                    } label: {
                        Label(section.title, systemImage: "bookmark.fill")
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Sample guide

/// A made-up field guide. The advice is general rock-pooling practice.
struct FieldGuide {
    enum Kind {
        case heading(symbol: String)
        case paragraph
    }

    struct Block: Identifiable {
        let id: Int
        let kind: Kind
        let text: String
        var wordCount: Int { text.split(separator: " ").count }
    }

    struct Section: Identifiable {
        let headingID: Int
        let title: String
        let symbol: String
        var id: Int { headingID }
    }

    static let tint = Color(hex: 0xA16207)

    let kicker: String
    let title: String
    let author: String
    let blocks: [Block]
    let sampleHighlights: Set<Int>
    let sampleBookmark: Int?

    var sections: [Section] {
        blocks.compactMap { block in
            if case .heading(let symbol) = block.kind {
                return Section(headingID: block.id, title: block.text, symbol: symbol)
            }
            return nil
        }
    }

    var readingMinutes: Int {
        max(1, Int((Double(blocks.reduce(0) { $0 + $1.wordCount }) / 200).rounded()))
    }

    func block(_ id: Int) -> Block? {
        blocks.first { $0.id == id }
    }

    func headingID(containing id: Int) -> Int? {
        sections.last { $0.headingID <= id }?.headingID
    }

    func minutes(in section: Section) -> Int {
        let next = sections.first { $0.headingID > section.headingID }?.headingID ?? Int.max
        let words = blocks.filter { $0.id >= section.headingID && $0.id < next }.reduce(0) { $0 + $1.wordCount }
        return max(1, Int((Double(words) / 200).rounded()))
    }

    static let lowTide: FieldGuide = {
        let parts: [(Kind, String)] = [
            (.heading(symbol: "clock"), "Before you go"),
            (.paragraph, "The best rock pooling happens in the two hours either side of low tide. Check the time of low water for your beach the day before, not the morning of, so you can plan the walk down and leave a margin for the way back."),
            (.paragraph, "Wear shoes with a firm grip, and old socks over them if the rocks are green with weed. Bring a bucket, a small net with a soft mesh, and a hand lens if you have one. A phone in a zipped pocket is more use than a phone in your hand."),
            (.paragraph, "Tell someone where you are going and when you expect to be back. A rising tide cuts off headlands and gullies faster than you think, and the way you walked out is not always the way back."),
            (.heading(symbol: "water.waves"), "Reading a tide table"),
            (.paragraph, "Most coasts have two high tides and two low tides each day, a little over twelve hours apart. Each day they come about fifty minutes later than the day before, so last week's perfect timing will not work this week."),
            (.paragraph, "The height column matters as much as the time. It gives the water level in metres above chart datum, roughly the lowest the tide usually falls. The smaller the number at low water, the more of the shore you will see."),
            (.paragraph, "Spring tides have nothing to do with the season. They arrive a day or two after a full or a new moon, give the lowest lows of the month, and are the only time the lower shore comes out of the water."),
            (.heading(symbol: "sun.max"), "The upper shore"),
            (.paragraph, "Closest to the cliffs, the rocks spend most of the day dry. Only the toughest animals live here: acorn barnacles glued in crowds, and limpets that clamp down so hard that you cannot lift them without hurting them."),
            (.paragraph, "Look at the seaweeds in bands as you walk down. Channelled wrack curls up and turns black in the sun, then softens again when the tide returns. Each band shows how long its plants can stay out of the water."),
            (.heading(symbol: "fish"), "The middle shore"),
            (.paragraph, "This is where the best pools are. A pool that keeps its water at low tide is a small, warm, crowded world, and it rewards patience more than searching. Sit still at the edge for a minute before you touch anything."),
            (.paragraph, "Beadlet anemones fold into red blobs of jelly when the tide is out and open into soft crowns when they are covered. Brush a tentacle with a fingertip and it clings for a moment: a sting far too weak for you to feel."),
            (.paragraph, "Shore crabs back into gaps under ledges and raise their claws when cornered. Pick one up from behind, across the back of the shell, and it cannot reach you. Put it back where you found it, facing the gap it came from."),
            (.paragraph, "Blennies are the small brown fish that dart between stones and then freeze, trusting their camouflage. Under damp weed they can last for hours out of the water, waiting for the tide like everyone else."),
            (.heading(symbol: "leaf"), "The lower shore"),
            (.paragraph, "Only the lowest spring tides uncover this zone, and it looks like another country. Kelp lies flat in heavy brown ribbons, and under it you may find starfish, brittle stars and the striped shells of top snails."),
            (.paragraph, "Watch the water as much as the pools. The tide turns without a signal, and on a flat shore it can come in faster than you can walk on wet rock. When the first pools start to fill, start back."),
            (.heading(symbol: "hand.raised"), "Leave it as you found it"),
            (.paragraph, "Turn rocks over gently and always turn them back the same way up. The underside is home to animals that cannot survive the sun, and a rock left upside down kills the life on both of its faces."),
            (.paragraph, "Keep animals in your bucket for minutes, not hours, in plenty of cool seawater and out of the sun. Return them to the pool they came from, not the nearest one, and carry home any litter the sea has left behind.")
        ]
        let blocks = parts.enumerated().map { index, part in
            Block(id: index + 1, kind: part.0, text: part.1)
        }
        return FieldGuide(kicker: "A field guide to rock pools",
                          title: "The Shore at Low Tide",
                          author: "Maren Holt",
                          blocks: blocks,
                          sampleHighlights: [7, 13],
                          sampleBookmark: 6)
    }()
}
