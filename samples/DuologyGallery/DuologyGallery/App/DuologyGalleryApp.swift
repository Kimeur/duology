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
    /// Starts from `-showsRegions YES`, or else from the last saved choice.
    /// View state, not `@AppStorage`: a launch argument wins over anything the
    /// app writes to its defaults, so `@AppStorage` would read the argument
    /// back and the button could never turn the overlay off.
    @State private var showsRegions = UserDefaults.standard.bool(forKey: "showsRegions")

    var body: some View {
        GalleryHome(openPattern: $openPattern, showsRegions: $showsRegions)
            .onChange(of: showsRegions) { _, isOn in
                // Saved for the next launch without the argument.
                UserDefaults.standard.set(isOn, forKey: "showsRegions")
            }
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
