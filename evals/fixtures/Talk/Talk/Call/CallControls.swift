import SwiftUI

struct CallControls: View {
    @Binding var isMuted: Bool
    @Binding var isCameraOn: Bool
    @Binding var isSpeakerOn: Bool
    @Binding var callEnded: Bool

    var body: some View {
        HStack(spacing: 20) {
            RoundControl(symbol: isMuted ? "mic.slash.fill" : "mic.fill", title: "Mute",
                         isOn: isMuted, tint: .white) { isMuted.toggle() }
                .accessibilityIdentifier("call.mute")

            RoundControl(symbol: isCameraOn ? "video.fill" : "video.slash.fill", title: "Camera",
                         isOn: !isCameraOn, tint: .white) { isCameraOn.toggle() }
                .accessibilityIdentifier("call.camera")

            RoundControl(symbol: isSpeakerOn ? "speaker.wave.2.fill" : "speaker.slash.fill", title: "Speaker",
                         isOn: !isSpeakerOn, tint: .white) { isSpeakerOn.toggle() }
                .accessibilityIdentifier("call.speaker")

            RoundControl(symbol: "phone.down.fill", title: "End", isOn: true, tint: .red) {
                callEnded = true
            }
            .accessibilityIdentifier("call.end")
        }
        .padding(16)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct RoundControl: View {
    let symbol: String
    let title: String
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint == .red ? .white : (isOn ? .black : .white))
                .frame(width: 60, height: 60)
                .background(Circle().fill(tint == .red ? .red : (isOn ? .white : .white.opacity(0.25))))
        }
        .accessibilityLabel(title)
    }
}
