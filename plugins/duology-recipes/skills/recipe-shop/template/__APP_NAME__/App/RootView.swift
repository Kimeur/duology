import SwiftUI

/// One navigation stack for every pose. Closed, it pushes the selected pack. Open, the shop
/// shows the pack in the trailing pane and only the basket is pushed. The store and the
/// model live here, above every layout change.
struct RootView: View {
    @State private var model = LaunchOptions.makeModel()
    @Environment(\.horizontalSizeClass) private var widthClass
    @State private var paneChange: Task<Void, Never>?

    var body: some View {
        NavigationStack(path: $model.path) {
            ShopScreen(model: model)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .pack(let id):
                        PackScreen(model: model, id: id)
                    case .basket:
                        BasketScreen(model: model)
                    }
                }
        }
        // The paywall covers the whole window, so it can use two panes on the inner display.
        .fullScreenCover(isPresented: $model.isPlusOpen) {
            PlusScreen(model: model)
        }
        // The window's width class, never the device or the pose: regular on the inner
        // display, compact on the outer display and in a narrow Split View window.
        .onChange(of: widthClass, initial: true) { oldValue, newValue in
            let isTwoPane = newValue == .regular
            paneChange?.cancel()
            // Opening the phone on a pushed pack pops it, and the screen under it comes back.
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
        .onChange(of: model.store.ownership) {
            model.ownershipChanged()
        }
        .task {
            await model.store.start()
        }
    }
}
