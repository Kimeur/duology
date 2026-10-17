import SwiftUI

struct SettingsView: View {
    var body: some View {
        GeometryReader { proxy in
            if proxy.size.height <= 667 {
                Text("Compact settings")
            } else {
                Text("Settings")
            }
        }
    }
}
