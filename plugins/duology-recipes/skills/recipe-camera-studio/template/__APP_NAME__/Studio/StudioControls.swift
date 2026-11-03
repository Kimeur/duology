import SwiftUI
import UIKit

/// The studio's controls: the gallery, the self-timer, the shutter, photo or video, the camera
/// switch, and the subject view's switch when the system offers it. The same controls in every
/// pose; only the direction changes: a row along the bottom, or a column along the trailing
/// edge (folded like a book, or a wide screen).
struct StudioControls: View {
    let store: StudioStore
    let edge: StudioLayout.ControlsEdge
    /// Over the preview (closed, or open and flat), rather than in a region of their own.
    let floats: Bool

    var body: some View {
        let stack = edge == .bottom
            ? AnyLayout(HStackLayout(alignment: .center, spacing: 8))
            : AnyLayout(VStackLayout(alignment: .center, spacing: 8))
        stack {
            galleryButton
            timerButton
            ShutterButton(store: store)
            modeButton
            switchButton
            if store.subjectViewAvailable {
                subjectButton
            }
        }
        .padding(12)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(floats ? AnyShapeStyle(.black.opacity(0.45)) : AnyShapeStyle(.black))
        .foregroundStyle(.white)
        .frameMarker("studio.controlsRegion")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Camera controls")
    }

    /// The latest capture, small; opens the gallery.
    private var galleryButton: some View {
        Button {
            store.showsGallery = true
        } label: {
            Group {
                if let latest = store.library.latest, let image = UIImage(contentsOfFile: store.posterURL(for: latest).path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.white.opacity(0.6)))
        }
        .frame(minWidth: 52, minHeight: 52)
        .frame(maxWidth: edge == .bottom ? .infinity : nil, maxHeight: edge == .trailing ? .infinity : nil)
        .accessibilityLabel(store.library.latest.map { "Gallery, latest: \($0.spokenTitle)" } ?? "Gallery, empty")
        .accessibilityIdentifier("studio.gallery")
    }

    private var timerButton: some View {
        Button {
            store.timer = store.timer.next
        } label: {
            VStack(spacing: 2) {
                Image(systemName: store.timer == .off ? "timer" : "timer.circle.fill")
                    .font(.title2)
                Text(store.timer.shortTitle)
                    .font(.caption2.bold())
            }
        }
        .controlTarget(edge)
        .disabled(store.countdown != nil || store.isRecording)
        .accessibilityLabel("Self-timer")
        .accessibilityValue(store.timer.title)
        .accessibilityIdentifier("studio.timer")
    }

    private var modeButton: some View {
        Button {
            store.setMode(store.mode == .photo ? .video : .photo)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: store.mode == .photo ? "camera" : "video")
                    .font(.title2)
                Text(store.mode.title)
                    .font(.caption2.bold())
            }
        }
        .controlTarget(edge)
        .disabled(store.isRecording || store.countdown != nil)
        .accessibilityLabel("Mode")
        .accessibilityValue(store.mode.title)
        .accessibilityHint("Switches between photo and video")
        .accessibilityIdentifier("studio.mode")
    }

    private var switchButton: some View {
        Button("Switch Camera", systemImage: "arrow.triangle.2.circlepath.camera") {
            store.switchCamera()
        }
        .labelStyle(.iconOnly)
        .font(.title2)
        .controlTarget(edge)
        .disabled(store.usesStandIn || store.isRecording)
        .accessibilityIdentifier("studio.switch")
    }

    /// Turns the outer display's subject view off and on. The system decides whether it can
    /// show; the photographer decides whether it does.
    private var subjectButton: some View {
        Button(AppFacts.subjectViewTitle, systemImage: store.showsSubjectView ? "person.crop.rectangle.fill" : "person.crop.rectangle") {
            store.showsSubjectView.toggle()
        }
        .labelStyle(.iconOnly)
        .font(.title2)
        .controlTarget(edge)
        .accessibilityValue(store.showsSubjectView ? "On" : "Off")
        .accessibilityIdentifier("studio.subject")
    }
}

/// The shutter: a white circle for a photo, red for video, a red square while recording.
/// During a countdown it cancels the countdown.
struct ShutterButton: View {
    let store: StudioStore

    var body: some View {
        Button {
            store.shutter()
        } label: {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 76, height: 76)
                if store.isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.red)
                        .frame(width: 30, height: 30)
                } else {
                    Circle()
                        .fill(store.mode == .photo ? Color.white : Color.red)
                        .frame(width: 62, height: 62)
                }
                if store.countdown != nil {
                    Image(systemName: "xmark")
                        .font(.title.bold())
                        .foregroundStyle(.black)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(store.isSaving)
        .accessibilityLabel(label)
        .accessibilityIdentifier("studio.shutter")
    }

    private var label: String {
        if store.countdown != nil { return "Cancel Self-Timer" }
        if store.isRecording { return "Stop Recording" }
        return store.mode == .photo ? "Take Photo" : "Start Recording"
    }
}

private extension View {
    /// At least 52 pt, and an equal share of the row or column.
    func controlTarget(_ edge: StudioLayout.ControlsEdge) -> some View {
        frame(minWidth: 52, minHeight: 52)
            .frame(maxWidth: edge == .bottom ? .infinity : nil, maxHeight: edge == .trailing ? .infinity : nil)
            .contentShape(Rectangle())
    }
}
