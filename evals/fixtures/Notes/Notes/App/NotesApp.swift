import SwiftUI

@main
struct NotesApp: App {
    @State private var store = NoteStore()

    var body: some Scene {
        WindowGroup {
            NoteList()
                .environment(store)
        }
    }
}
