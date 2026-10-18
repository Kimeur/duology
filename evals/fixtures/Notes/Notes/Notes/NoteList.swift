import SwiftUI

struct NoteList: View {
    @Environment(NoteStore.self) private var store
    @State private var path: [Note.ID] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(store.notes) { note in
                    NavigationLink(value: note.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.title).font(.headline)
                            Text(note.edited, style: .relative)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        Button("Duplicate", systemImage: "plus.square.on.square") {
                            store.duplicate(note.id)
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            store.delete(note.id)
                        }
                    }
                }
            }
            .navigationTitle("Notes")
            .navigationDestination(for: Note.ID.self) { id in
                NoteEditor(id: id)
            }
            .toolbar {
                Button("New Note", systemImage: "square.and.pencil") {
                    path.append(store.add().id)
                }
            }
        }
    }
}
