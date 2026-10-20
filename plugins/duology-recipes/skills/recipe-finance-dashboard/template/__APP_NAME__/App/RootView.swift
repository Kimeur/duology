import SwiftUI

/// One navigation stack for every pose. Closed, it pushes the selected transaction. Open,
/// the dashboard shows it in the trailing pane and the path stays empty.
struct RootView: View {
    @State private var model = LaunchOptions.makeModel()
    @Environment(\.horizontalSizeClass) private var widthClass
    @State private var paneChange: Task<Void, Never>?

    var body: some View {
        NavigationStack(path: $model.path) {
            DashboardScreen(model: model)
                .navigationDestination(for: LedgerEntry.ID.self) { id in
                    TransactionScreen(model: model, id: id)
                }
        }
        // The window's width class, never the device or the pose: regular on the inner
        // display, compact on the outer display and in a narrow Split View window.
        .onChange(of: widthClass, initial: true) { oldValue, newValue in
            let isTwoPane = newValue == .regular
            paneChange?.cancel()
            // Opening the phone on a pushed transaction pops it, and the screen under it comes back.
            // Popped during the fold animation, that screen kept a stale safe area and lost
            // its margins until relaunch (measured on the simulator). Popped once the
            // animation is over, it lays out right. The first call, at launch, needs no wait.
            if isTwoPane, oldValue != newValue, !model.isTwoPane, model.selection != nil {
                paneChange = Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    guard !Task.isCancelled else { return }
                    model.isTwoPane = true
                }
            } else {
                model.isTwoPane = isTwoPane
            }
        }
    }
}
