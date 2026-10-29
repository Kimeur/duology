import SwiftUI

/// Every note, newest first, as cards. Closed: one column. Open and held wide, flat or like a
/// book: two columns that meet at the fold's frame, so no card lies on it. Wider windows
/// without a fold (tabletop, an iPad): as many columns as fit. New Note sits in the
/// navigation bar, which keeps itself off the fold.
struct NotesListScreen: View {
    let store: NotesStore

    @State private var fold = FoldGeometry()
    @State private var width: CGFloat = 0

    var body: some View {
        let columns = NoteColumns(width: width, fold: fold)
        let rows = rows(of: store.notes, columns: columns.columns.count)
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(rows, id: \.first?.id) { row in
                    ColumnsRow(columns: columns.columns) {
                        ForEach(row) { note in
                            NoteCard(note: note, store: store)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .onFoldChange { fold = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .foldMarker(fold)
        .overlay {
            if store.notes.isEmpty {
                ContentUnavailableView("No Notes", systemImage: "note.text",
                                       description: Text("Tap New Note to write one."))
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Note", systemImage: "square.and.pencil") { store.newNote() }
                    .accessibilityIdentifier("list.new")
            }
        }
        .testMarker("list.state", value: [
            "count=\(store.notes.count)",
            "columns=\(columns.columns.count)",
            "foldsBetween=\(columns.foldsBetween ? 1 : 0)",
            "width=\(Int(width))",
            "fold=\(fold.markerText)",
            "ids=\(store.notes.map(\.id).joined(separator: ","))",
        ].joined(separator: "|") + "|")
    }

    private func rows(of notes: [Note], columns: Int) -> [[Note]] {
        stride(from: 0, to: notes.count, by: max(1, columns)).map { Array(notes[$0..<min($0 + max(1, columns), notes.count)]) }
    }
}

/// One note in the list: its title, its first lines, its summary's headline if it has one,
/// and when it last changed. Tap to open; touch and hold to delete.
struct NoteCard: View {
    let note: Note
    let store: NotesStore

    var body: some View {
        Button {
            store.open(note.id)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(note.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                if !note.preview.isEmpty {
                    Text(note.preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let digest = note.digest {
                    Label(digest.headline, systemImage: digest.origin == .onDeviceAI ? "sparkles" : "text.alignleft")
                        .font(.footnote)
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                        .accessibilityLabel("Summary: \(digest.headline)")
                }
                Spacer(minLength: 0)
                Text(note.modified, format: .dateTime.day().month().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
            .frame(minHeight: 88)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete Note", systemImage: "trash", role: .destructive) { store.delete(note.id) }
        }
        .accessibilityIdentifier("note.card.\(note.id)")
    }
}
