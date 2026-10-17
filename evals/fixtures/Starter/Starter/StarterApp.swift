import SwiftUI

@main
struct StarterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.wave")
                .font(.largeTitle)
            Text("Hello")
        }
        .padding()
    }
}
