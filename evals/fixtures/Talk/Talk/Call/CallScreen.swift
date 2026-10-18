import SwiftUI
import UIKit

/// A video call in progress. The videos are placeholders; there is no real call.
struct CallScreen: View {
    @State private var isMuted = false
    @State private var isCameraOn = true
    @State private var isSpeakerOn = true
    @State private var callEnded = false

    var body: some View {
        ZStack {
            RemoteVideoView(name: "Sam Rivera")
                .ignoresSafeArea()

            VStack {
                HStack(alignment: .top) {
                    CallTimerLabel()
                    Spacer()
                    SelfView(isCameraOn: isCameraOn)
                        .frame(width: UIScreen.main.bounds.width * 0.28,
                               height: UIScreen.main.bounds.width * 0.28 * 4 / 3)
                }
                .padding()

                Spacer()

                if UIDevice.current.orientation.isLandscape {
                    // Landscape: controls along the bottom, spread out.
                    CallControls(isMuted: $isMuted, isCameraOn: $isCameraOn,
                                 isSpeakerOn: $isSpeakerOn, callEnded: $callEnded)
                        .padding(.horizontal, 80)
                        .padding(.bottom, 16)
                } else {
                    CallControls(isMuted: $isMuted, isCameraOn: $isCameraOn,
                                 isSpeakerOn: $isSpeakerOn, callEnded: $callEnded)
                        .padding(.bottom, 32)
                }
            }
        }
        .alert("Call ended", isPresented: $callEnded) {
            Button("OK", role: .cancel) {}
        }
    }
}

struct RemoteVideoView: View {
    let name: String

    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .black], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 12) {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .overlay(Text("SR").font(.system(size: 56, weight: .semibold)).foregroundStyle(.white))
                Text(name)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Video from \(name)")
    }
}

struct SelfView: View {
    let isCameraOn: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isCameraOn ? Color.teal : Color.gray)
            .overlay(
                Image(systemName: isCameraOn ? "person.fill" : "video.slash.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            )
            .accessibilityLabel("Your video")
    }
}

struct CallTimerLabel: View {
    @State private var start = Date()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = Int(context.date.timeIntervalSince(start))
            Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
                .padding(8)
                .background(.black.opacity(0.4), in: Capsule())
        }
    }
}
