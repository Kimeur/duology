import SwiftUI

@main
struct AlbumApp: App {
    var body: some Scene {
        WindowGroup {
            AlbumScreen(album: .nightDrive)
        }
    }
}
