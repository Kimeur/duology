import SwiftUI

struct NoteEditor: View {
    @Environment(NoteStore.self) private var store
    let id: Note.ID

    var body: some View {
        if let note = store.note(id) {
            TextEditor(text: Binding(
                get: { note.text },
                set: { store.update(id, text: $0) }
            ))
            .padding(.horizontal)
            .navigationTitle(note.title)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Note deleted", systemImage: "trash")
        }
    }
}
