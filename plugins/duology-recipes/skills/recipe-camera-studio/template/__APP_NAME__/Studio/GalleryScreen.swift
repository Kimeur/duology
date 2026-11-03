import AVKit
import SwiftUI
import UIKit

/// The photos and videos made in the studio, newest first. They stay in the app; Share sends
/// one on (and offers Save to Photos). Shown in a sheet from the studio.
struct GalleryScreen: View {
    let store: StudioStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 4)], spacing: 4) {
                    ForEach(store.library.sorted) { capture in
                        NavigationLink(value: capture.id) {
                            PosterCell(capture: capture, url: store.posterURL(for: capture))
                        }
                        .accessibilityLabel(capture.spokenTitle)
                        .accessibilityIdentifier("gallery.cell.\(capture.id)")
                    }
                }
                .padding(4)
            }
            .overlay {
                if store.library.captures.isEmpty {
                    ContentUnavailableView("No Photos Yet", systemImage: "camera",
                                           description: Text("Photos and videos you take in the studio appear here."))
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Capture.ID.self) { id in
                if let capture = store.library.capture(id) {
                    CaptureDetail(capture: capture, store: store)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("gallery.done")
                }
            }
            .testMarker("gallery.state", value: "count=\(store.library.captures.count)|")
        }
    }
}

/// One square in the grid: the photo, or the video's poster with its length.
struct PosterCell: View {
    let capture: Capture
    let url: URL

    var body: some View {
        Color.gray.opacity(0.3)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                // Small galleries load fast enough like this; downsample with ImageIO for big ones.
                if let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if capture.kind == .video {
                    Label(RecordingClock.text(capture.duration ?? 0), systemImage: "video.fill")
                        .font(.caption2.bold())
                        .padding(4)
                        .background(.black.opacity(0.6), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(4)
                }
            }
    }
}

/// One photo or video, with Share and Delete.
struct CaptureDetail: View {
    let capture: Capture
    let store: StudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDelete = false
    /// Made once, not on every pass of `body`.
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if capture.kind == .video {
                VideoPlayer(player: player)
                    .onAppear { if player == nil { player = AVPlayer(url: store.url(for: capture)) } }
            } else if let image = UIImage(contentsOfFile: store.url(for: capture).path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(capture.spokenTitle)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .navigationTitle(capture.created.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: store.url(for: capture))
                    .accessibilityIdentifier("gallery.share")
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                    .accessibilityIdentifier("gallery.delete")
            }
        }
        .confirmationDialog("Delete this \(capture.kind == .photo ? "photo" : "video")?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button(capture.kind == .photo ? "Delete Photo" : "Delete Video", role: .destructive) {
                store.delete(capture.id)
                dismiss()
            }
        }
    }
}
