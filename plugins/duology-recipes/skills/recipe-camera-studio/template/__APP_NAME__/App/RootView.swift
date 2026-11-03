import SwiftUI

/// The window's root. It owns the one `StudioStore` and the gallery sheet, and never changes
/// identity: a fold resizes what's below it but never rebuilds the store, so a countdown, a
/// recording and the camera session all carry on.
struct RootView: View {
    @State private var store = StudioStore.launch()

    var body: some View {
        StudioScreen(store: store)
            // Attached here, on a view that never changes identity, so a fold can't close it.
            .sheet(isPresented: $store.showsGallery) {
                GalleryScreen(store: store)
            }
    }
}
