import SwiftUI

/// The window's root. It owns the one `NotesStore` (and with it the summary in progress), the
/// navigation stack and the summary sheet, and never changes identity: a fold resizes what's
/// below it but never rebuilds the store, the path or the sheet, so the note, the cursor's
/// note and a summary still streaming in all stay.
struct RootView: View {
    @State private var store = NotesStore.launch()

    var body: some View {
        NavigationStack(path: $store.path) {
            NotesListScreen(store: store)
                .navigationDestination(for: Note.ID.self) { id in
                    NoteScreen(noteID: id, store: store)
                }
        }
        // Attached here, on a view that never changes identity, so a fold can't close it.
        // NoteScreen closes it when the pane fits beside the note.
        .sheet(isPresented: $store.showsSummarySheet) {
            SummarySheet(store: store)
        }
    }
}
