import SwiftUI

@main
struct __APP_NAME__App: App {
    init() {
        LaunchOptions.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

enum AppInfo {
    static let name = "__APP_NAME__"
}
