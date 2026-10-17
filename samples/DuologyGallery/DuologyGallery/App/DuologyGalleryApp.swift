import SwiftUI

@main
struct DuologyGalleryApp: App {
    var body: some Scene {
        WindowGroup {
            GalleryRoot()
        }
    }
}

/// The home screen, with each pattern presented full screen on top of it.
///
/// Patterns are full-screen covers, not pushed screens, because several of them
/// own their navigation container (`NavigationSplitView`, `TabView`). Navigation
/// containers go at the root of a screen, never inside another stack.
struct GalleryRoot: View {
    @State private var openPattern: Pattern? = LaunchOptions.pattern
    /// `-showsRegions YES` on launch overrides this, because launch arguments
    /// sit above the app's own defaults.
    @AppStorage("showsRegions") private var showsRegions = false

    var body: some View {
        GalleryHome(openPattern: $openPattern, showsRegions: $showsRegions)
            .fullScreenCover(item: $openPattern) { pattern in
                pattern.screen
                    .environment(\.closePattern, ClosePatternAction { openPattern = nil })
                    .overlay {
                        if showsRegions {
                            ReservedRegionOverlay()
                        }
                    }
            }
    }
}
