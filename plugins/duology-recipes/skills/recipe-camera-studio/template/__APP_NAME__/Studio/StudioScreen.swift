import SwiftUI
import UIKit

/// The studio: the camera preview and the controls.
///
/// - Closed, or open and flat: the preview fills the screen and the controls float over it,
///   along the bottom when the screen is tall, along the trailing edge when it is wide.
/// - Folded like a book: the preview on the left page, the controls on the right.
/// - Tabletop: the preview above the fold, the controls below it, on the half that rests on
///   the table, for hands-free shots with the self-timer.
/// - Open, with the rear camera: the subject view on the outer display (`SubjectView`).
///
/// One `StudioSplit` for every pose, so the preview's view and its layer are never rebuilt.
/// The countdown and the recording live in the store, so a fold never stops them.
struct StudioScreen: View {
    let store: StudioStore

    @State private var fold = FoldGeometry()
    @State private var size = CGSize.zero
    @ScaledMetric(relativeTo: .body) private var controlsThickness = StudioLayout.controlsThickness

    private var layout: StudioLayout { StudioLayout(size: size, fold: fold, controlsThickness: controlsThickness) }

    var body: some View {
        StudioSplit(fold: fold, controlsThickness: controlsThickness) {
            PreviewArea(store: store)
            StudioControls(store: store, edge: layout.edge, floats: layout.controlsFloat)
        }
        .onFoldChange { fold = $0 }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .foldMarker(fold)
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .subjectAccessory(store)
        // Runs once: this screen never changes identity, a fold only resizes it.
        .task { await store.prepare() }
        .testMarker("studio.state", value: testSummary)
    }

    private var testSummary: String {
        let latest = store.library.latest
        return [
            "camera=\(store.usesStandIn ? "standin" : "real")",
            "access=\(store.access.rawValue)",
            "mode=\(store.mode.rawValue)",
            "side=\(store.side.rawValue)",
            "timer=\(store.timer.rawValue)",
            "countdown=\(store.countdown.map { "\($0.left)" } ?? "")",
            "recording=\(store.isRecording ? 1 : 0)",
            "saving=\(store.isSaving ? 1 : 0)",
            "captures=\(store.library.captures.count)",
            "latest=\(latest?.kind.rawValue ?? "")",
            "latestDuration=\(latest?.duration.map { String(format: "%.1f", $0) } ?? "")",
            "layout=\(layout.mode.rawValue)",
            "edge=\(layout.edge.rawValue)",
            "size=\(Int(size.width))x\(Int(size.height))",
            "fold=\(fold.markerText)",
            "folded=\(fold.isActive ? 1 : 0)",
            "subjectAvailable=\(store.subjectViewAvailable ? 1 : 0)",
            "subjectOn=\(store.showsSubjectView ? 1 : 0)",
            "error=\(store.lastError ?? "")",
        ].joined(separator: "|") + "|"
    }
}

/// The preview, with the countdown and the recording time over it.
struct PreviewArea: View {
    let store: StudioStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            if let capture = store.capture, store.access == .authorized {
                CameraPreview(source: capture.previewSource) { _ in
                    Task { await capture.refreshRotation() }
                }
            } else if store.usesStandIn {
                StandInPreview()
            } else {
                Color.black
            }
        }
        .overlay(alignment: .top) { statusLine.padding(12) }
        .overlay { CountdownBadge(countdown: store.countdown, size: 140) }
        .overlay(alignment: .center) { accessMessage }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .clipped()
        .frameMarker("studio.previewRegion")
    }

    @ViewBuilder
    private var statusLine: some View {
        if let started = store.recordingStarted {
            RecordingBadge(started: started)
        } else if store.usesStandIn {
            Label("Stand-in camera", systemImage: "camera.metering.unknown")
                .font(.footnote.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.6), in: Capsule())
                .foregroundStyle(.white)
        }
    }

    /// Why there is no picture, when the reason is one people can act on.
    @ViewBuilder
    private var accessMessage: some View {
        if !store.usesStandIn, let message = store.access.message {
            VStack(spacing: 12) {
                Text(message)
                    .multilineTextAlignment(.center)
                if store.access.opensSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                    Button("Open Settings") { openURL(url) }
                        .buttonStyle(.borderedProminent)
                }
            }
            .foregroundStyle(.white)
            .padding(24)
        }
    }
}

/// The self-timer's seconds, large, over the preview. Also shown on the outer display.
struct CountdownBadge: View {
    let countdown: Countdown?
    var size: CGFloat

    var body: some View {
        if let countdown {
            Text("\(countdown.left)")
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(radius: 12)
                .contentTransition(.numericText(countsDown: true))
                .accessibilityLabel("\(countdown.left) seconds")
                .accessibilityIdentifier("studio.countdown")
        }
    }
}

/// "REC 0:07", counting up while a video records.
struct RecordingBadge: View {
    let started: Date
    var large = false

    var body: some View {
        TimelineView(.periodic(from: started, by: 1)) { context in
            let seconds = context.date.timeIntervalSince(started)
            Label(RecordingClock.text(seconds), systemImage: "record.circle.fill")
                .font(large ? .system(size: 64, weight: .bold, design: .rounded) : .headline)
                .monospacedDigit()
                .padding(.horizontal, large ? 24 : 12)
                .padding(.vertical, large ? 12 : 6)
                .background(.red, in: Capsule())
                .foregroundStyle(.white)
                .accessibilityLabel("Recording, \(RecordingClock.spoken(seconds))")
                .accessibilityIdentifier("studio.recording")
        }
    }
}
