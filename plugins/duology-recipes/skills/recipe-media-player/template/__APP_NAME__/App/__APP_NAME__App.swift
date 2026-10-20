import AVFoundation
import SwiftUI

@main
struct __APP_NAME__App: App {
    init() {
        LaunchOptions.configure()
        // The playback category lets sound play with the ring switch off. With the
        // audio background mode in Info.plist, it also lets audio go on in the
        // background and Picture in Picture start.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
