import SwiftUI
import UIKit

struct RootView: View {
    var body: some View {
        TabView {
            PlacesScreen()
                .tabItem { Label("Places", systemImage: "map") }

            GalleryScreen()
                .tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }

            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        // Bigger text on iPad.
        .dynamicTypeSize(UIDevice.current.userInterfaceIdiom == .pad ? .xLarge : .large)
    }
}
