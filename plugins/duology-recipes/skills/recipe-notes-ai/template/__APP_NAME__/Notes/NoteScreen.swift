import SwiftUI

/// One note: the editor, and its summary.
///
/// - Closed: the note fills the screen; the summary is a one-line bar at the bottom, and
///   Details opens the full summary in a sheet.
/// - Open and held wide, or folded like a book: the note on the left page, the summary pane on
///   the right, with the fold between them.
/// - Tabletop (and open, held tall): the note above the fold, the summary pane below it, on the
///   half that rests on the table, where its buttons are.
///
/// One `PaneSplit` for every pose, so a fold never rebuilds the editor or the summary. The
/// summary in progress lives in the store's `SummaryService`, so it keeps streaming through
/// any fold, and even when this screen is closed.
struct NoteScreen: View {
    let noteID: Note.ID
    let store: NotesStore

    @State private var fold = FoldGeometry()
    @State private var size = CGSize.zero
    @State private var confirmsDelete = false
    @ScaledMetric(relativeTo: .body) private var barHeight = 64.0

    private var layout: NoteLayout { NoteLayout(size: size, fold: fold, barHeight: barHeight) }

    var body: some View {
        if let note = store.note(noteID) {
            PaneSplit(fold: fold, barHeight: barHeight) {
                EditorPane(noteID: noteID, store: store)
                if layout.hasSummaryPane {
                    SummaryPane(noteID: noteID, store: store)
                } else {
                    SummaryBar(noteID: noteID, store: store)
                }
            }
            .onFoldChange { fold = $0 }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .foldMarker(fold)
            // Tabletop: the keyboard covers the summary pane below the fold and leaves the note
            // above it alone, instead of squeezing both. Elsewhere the panes make room for it.
            .ignoresSafeArea(layout.mode == .foldTopBottom ? .keyboard : [], edges: .bottom)
            .background(Color(.systemBackground))
            .navigationTitle(note.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("More", systemImage: "ellipsis.circle") {
                        if note.digest != nil {
                            Button("Clear Summary", systemImage: "xmark.circle") { store.clearSummary(of: noteID) }
                        }
                        Button("Delete Note", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                    }
                    .accessibilityIdentifier("note.more")
                }
            }
            .confirmationDialog("Delete this note?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Delete Note", role: .destructive) { store.delete(noteID) }
            }
            // The pane now fits beside the note: the sheet's job is done.
            .onChange(of: layout.hasSummaryPane) { _, hasPane in
                if hasPane { store.showsSummarySheet = false }
            }
            .testMarker("note.state", value: testSummary(note))
        } else {
            ContentUnavailableView("Note Deleted", systemImage: "trash")
        }
    }

    private func testSummary(_ note: Note) -> String {
        let service = store.summaries
        let digest = note.digest
        return [
            "id=\(note.id)",
            "mode=\(layout.mode.rawValue)",
            "size=\(Int(size.width))x\(Int(size.height))",
            "fold=\(fold.markerText)",
            "folded=\(fold.isActive ? 1 : 0)",
            "words=\(note.wordCount)",
            "phase=\(service.isWorking(on: note.id) ? "working" : "idle")",
            "draft=\(service.isWorking(on: note.id) ? service.draft?.headline ?? "" : "")",
            "draftPoints=\(service.isWorking(on: note.id) ? service.draft?.points.count ?? 0 : 0)",
            "digest=\(digest?.origin.rawValue ?? "none")",
            "headline=\(digest?.headline ?? "")",
            "points=\(digest?.points.count ?? 0)",
            "todos=\(digest?.todos.count ?? 0)",
            "current=\(note.summaryIsCurrent ? 1 : 0)",
            "fallback=\(digest?.fallbackReason == nil ? 0 : 1)",
            "sheet=\(store.showsSummarySheet ? 1 : 0)",
            "engine=\(service.engine.rawValue)",
            "unavailable=\(service.unavailableReason ?? "")",
        ].joined(separator: "|") + "|"
    }
}

/// The title and the text. Both write to the store on every change, so nothing typed is lost
/// to a fold, a crash or quitting.
struct EditorPane: View {
    let noteID: Note.ID
    let store: NotesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: Binding(get: { store.note(noteID)?.title ?? "" },
                                             set: { store.setTitle($0, of: noteID) }), axis: .vertical)
                .font(.title2.bold())
                .lineLimit(1...3)
                .accessibilityIdentifier("note.title")
            TextEditor(text: Binding(get: { store.note(noteID)?.body ?? "" },
                                     set: { store.setBody($0, of: noteID) }))
                .font(.body)
                .scrollContentBackground(.hidden)
                .accessibilityLabel("Note")
                .accessibilityIdentifier("note.body")
                .overlay(alignment: .topLeading) {
                    if store.note(noteID)?.body.isEmpty ?? true {
                        Text("Write your note")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .frameMarker("note.editorPane")
    }
}
