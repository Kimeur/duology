import SwiftUI

/// The window's root. It owns the one `LibraryStore` and the navigation stack, and
/// never changes identity: the library, the reader and every layout decision sit
/// below it. A fold resizes what's below; it never rebuilds the store or the path,
/// so the reader stays open at the same place.
struct RootView: View {
    @State private var store = LibraryStore.launch()

    var body: some View {
        NavigationStack(path: $store.path) {
            LibraryView(store: store)
                .navigationDestination(for: Book.ID.self) { id in
                    if let book = store.library.book(id) {
                        ReaderScreen(book: book, store: store)
                    }
                }
        }
    }
}
