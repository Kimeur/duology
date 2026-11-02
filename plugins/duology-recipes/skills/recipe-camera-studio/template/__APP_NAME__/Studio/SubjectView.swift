import SwiftUI

/// What the person in front of the rear camera sees on the outer display while the phone is
/// open: their own picture, mirrored like a mirror, a framing guide, and the countdown or the
/// recording time, large. Nothing to tap: the system can take it away at any moment, and the
/// photographer's controls never depend on it.
///
/// The system builds a new accessory scene each time the phone opens (measured in
/// `duo-scenes`), so this view holds no state of its own; it reads the store.
struct SubjectView: View {
    let store: StudioStore

    var body: some View {
        ZStack {
            if let capture = store.capture, store.access == .authorized, store.side == .back {
                // A second preview layer on the same session, with its own rotation coordinator.
                // From the outer display the rear camera faces the subject: mirror it.
                CameraPreview(source: capture.previewSource, gravity: .resizeAspectFill) { view in
                    let layer = ObjectIdentifier(view.previewLayer)
                    Task { await capture.attachSubjectPreview(layer, mirrored: true) }
                }
            } else if store.usesStandIn, store.side == .back {
                StandInPreview(mirrored: true)
            } else {
                Color.black
            }
            ThirdsGuide()
        }
        .overlay { status }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Subject view")
        .testMarker("subject.state", value: [
            "countdown=\(store.countdown.map { "\($0.left)" } ?? "")",
            "recording=\(store.isRecording ? 1 : 0)",
            "mirrored=\(store.side == .back ? 1 : 0)",
        ].joined(separator: "|") + "|")
    }

    @ViewBuilder
    private var status: some View {
        if let countdown = store.countdown {
            CountdownBadge(countdown: countdown, size: 220)
        } else if let started = store.recordingStarted {
            RecordingBadge(started: started, large: true)
        } else {
            Text(AppFacts.subjectReadyLine)
                .font(.largeTitle.bold())
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.black.opacity(0.55), in: Capsule())
                .foregroundStyle(.white)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 48)
        }
    }
}

/// Two lines each way, at the thirds: where to put eyes and horizons.
struct ThirdsGuide: View {
    var body: some View {
        Canvas { canvas, size in
            var path = Path()
            for third in [1.0 / 3, 2.0 / 3] {
                path.move(to: CGPoint(x: size.width * third, y: 0))
                path.addLine(to: CGPoint(x: size.width * third, y: size.height))
                path.move(to: CGPoint(x: 0, y: size.height * third))
                path.addLine(to: CGPoint(x: size.width, y: size.height * third))
            }
            canvas.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Shows `SubjectView` on the outer display while this camera screen is on the inner one.
    /// Does nothing before iOS 27.1 or on Mac Catalyst (`duo-scenes`).
    @ViewBuilder
    func subjectAccessory(_ store: StudioStore) -> some View {
        #if !targetEnvironment(macCatalyst)
        if #available(iOS 27.1, *) {
            modifier(SubjectAccessory(store: store))
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#if !targetEnvironment(macCatalyst)
@available(iOS 27.1, *)
private struct SubjectAccessory: ViewModifier {
    @Bindable var store: StudioStore

    func body(content: Content) -> some View {
        content.sceneAccessory {
            CameraCaptureAccessory(isEnabled: $store.showsSubjectView) {
                SubjectView(store: store)
            }
            .onAvailabilityChange { store.subjectViewAvailable = $0 }
        }
    }
}
#endif
