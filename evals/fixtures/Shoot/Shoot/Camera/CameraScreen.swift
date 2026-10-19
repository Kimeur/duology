import SwiftUI

struct CameraScreen: View {
    @StateObject private var camera = CameraModel()

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()
            if !camera.isCameraAvailable {
                Label("Camera unavailable", systemImage: "video.slash")
                    .foregroundStyle(.white)
            }
            if let seconds = camera.secondsToStart {
                Text("\(seconds)")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityLabel("Recording starts in \(seconds)")
            }
        }
        .overlay(alignment: .top) {
            if camera.isRecording {
                Label(camera.elapsedText, systemImage: "record.circle.fill")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.red, in: Capsule())
                    .padding(.top, 12)
            }
        }
        .overlay(alignment: .bottom) {
            Button {
                camera.toggleRecording()
            } label: {
                Circle()
                    .fill(camera.isRecording ? .red : .white)
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(.white, lineWidth: 4).padding(-6))
            }
            .accessibilityLabel(camera.isRecording ? "Stop Recording" : "Record")
            .accessibilityIdentifier("shoot.record")
            .padding(.bottom, 32)
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }
}
