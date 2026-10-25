import SwiftUI

/// The window's root. It owns the one `LearningStore`, the navigation stack and the sheet
/// with the parental gate, and never changes identity: a fold resizes what's below it but
/// never rebuilds the store, the path or the sheet, so the stars, the question on screen
/// and a half-typed gate answer all stay.
struct RootView: View {
    @State private var store = LearningStore.launch()

    var body: some View {
        NavigationStack(path: $store.path) {
            HomeScreen(store: store)
                .navigationDestination(for: Activity.ID.self) { id in
                    if let activity = store.activity(id) {
                        LessonScreen(activity: activity, store: store)
                    }
                }
        }
        // Attached here, on a view that never changes identity, so a fold can't close it.
        .sheet(isPresented: $store.isGateOpen, onDismiss: { store.closeGate() }) {
            GrownupsSheet(store: store)
        }
    }
}
