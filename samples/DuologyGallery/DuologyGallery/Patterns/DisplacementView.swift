import SwiftUI

/// Displacement: voice memos with a record button.
///
/// The record controls are a group you place yourself, near the middle of the
/// screen. Partly folded like a book, the group slides to the trailing region
/// and keeps its bottom edge. Folded across, it goes to the bottom region. The
/// list of memos is scrolling content, so it never moves.
///
/// Built on the `.division` reserved region (iOS 27.1).
/// Pattern guide: `duo-patterns/references/displacement.md`.
struct DisplacementView: View {
    @State private var memos = VoiceMemo.samples
    @State private var fold = FoldGeometry()
    @State private var recordingSince: Date?
    @State private var playing: VoiceMemo.ID?

    var body: some View {
        NavigationStack {
            List {
                ForEach(memos) { memo in
                    MemoRow(memo: memo, isPlaying: playing == memo.id) {
                        playing = playing == memo.id ? nil : memo.id
                    }
                }
                .onDelete { memos.remove(atOffsets: $0) }
            }
            .listStyle(.plain)
            // Room under the last row, so the controls never hide it.
            .contentMargins(.bottom, 120, for: .scrollContent)
            .overlay {
                GeometryReader { proxy in
                    let region = controlRegion(in: proxy.size, fold: fold)
                    // One group moves as a unit, so the timer stays next to its button.
                    RecordControls(recordingSince: $recordingSince, onFinish: addMemo)
                        .frame(width: region.width, height: region.height, alignment: .bottom)
                        .position(x: region.midX, y: region.midY)
                }
                .onFoldChange { fold = $0 }
            }
            .animation(.smooth, value: fold)
            .navigationTitle("Voice Memos")
            .galleryCloseButton()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
        }
    }

    private func addMemo(length: TimeInterval) {
        let number = memos.filter { $0.title.hasPrefix("New Recording") }.count + 1
        let memo = VoiceMemo(id: (memos.map(\.id).max() ?? 0) + 1,
                             title: "New Recording \(number)", date: "Just now",
                             seconds: max(1, Int(length.rounded())))
        withAnimation(.smooth) { memos.insert(memo, at: 0) }
    }
}

// MARK: - Controls

private struct RecordControls: View {
    @Binding var recordingSince: Date?
    var onFinish: (TimeInterval) -> Void

    var body: some View {
        HStack(spacing: 16) {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                let elapsed = recordingSince.map { context.date.timeIntervalSince($0) } ?? 0
                HStack(spacing: 12) {
                    LevelMeter(time: context.date.timeIntervalSinceReferenceDate, isLive: recordingSince != nil)
                    Text(Duration.seconds(elapsed), format: .time(pattern: .minuteSecond(padMinuteToLength: 1, fractionalSecondsLength: 1)))
                        .font(.title3.monospacedDigit().weight(.medium))
                        .foregroundStyle(recordingSince == nil ? .secondary : .primary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(recordingSince == nil ? "Ready to record" : "Recording")

            Button(recordingSince == nil ? "Record" : "Stop", systemImage: recordingSince == nil ? "circle.fill" : "stop.fill") {
                if let start = recordingSince {
                    recordingSince = nil
                    onFinish(Date.now.timeIntervalSince(start))
                } else {
                    recordingSince = .now
                }
            }
            .labelStyle(.iconOnly)
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 58, height: 58)
            .background(Color.red.gradient, in: Circle())
            .contentShape(Circle())
            .sensoryFeedback(.impact, trigger: recordingSince == nil)
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: Capsule())
        .padding(.bottom, 20)
    }
}

/// A small live level meter. Flat while idle.
private struct LevelMeter: View {
    let time: TimeInterval
    let isLive: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<9, id: \.self) { bar in
                let wave = abs(sin(time * 7 + Double(bar) * 0.9)) * 0.7 + abs(sin(time * 3.1 + Double(bar))) * 0.3
                Capsule()
                    .fill(isLive ? Color.red : Color.secondary.opacity(0.5))
                    .frame(width: 3, height: isLive ? 6 + 22 * wave : 6)
            }
        }
        .frame(height: 30)
    }
}

// MARK: - Memos

private struct MemoRow: View {
    let memo: VoiceMemo
    let isPlaying: Bool
    var onPlay: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(memo.title)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(memo.date)
                    Text("·")
                    Text(Duration.seconds(memo.seconds), format: .time(pattern: .minuteSecond))
                        .monospacedDigit()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                MiniWaveform(seed: memo.id, progress: isPlaying ? 0.35 : 0)
                    .frame(height: 18)
            }
            Spacer(minLength: 0)
            Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill", action: onPlay)
                .labelStyle(.iconOnly)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(Color(.tertiarySystemFill), in: Circle())
                .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
}

/// A fixed waveform drawn from the memo's ID, so each memo keeps its own shape.
private struct MiniWaveform: View {
    let seed: Int
    let progress: Double

    var body: some View {
        Canvas { context, size in
            let count = 48
            let step = size.width / CGFloat(count)
            var generator = SeededGenerator(seed: UInt64(seed) &* 2_654_435_761)
            for index in 0..<count {
                let level = 0.2 + 0.8 * Double(generator.next() % 1000) / 1000
                let height = max(2, size.height * level)
                let rect = CGRect(x: CGFloat(index) * step, y: (size.height - height) / 2,
                                  width: max(1.5, step * 0.55), height: height)
                let played = Double(index) / Double(count) < progress
                context.fill(Path(roundedRect: rect, cornerRadius: 1),
                             with: .color(played ? .red : Color.secondary.opacity(0.45)))
            }
        }
        .accessibilityHidden(true)
    }
}

/// A tiny deterministic random generator (SplitMix64), for stable sample waveforms.
private struct SeededGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

struct VoiceMemo: Identifiable, Hashable {
    let id: Int
    var title: String
    var date: String
    var seconds: Int

    static let samples: [VoiceMemo] = [
        VoiceMemo(id: 1, title: "Kitchen renovation ideas", date: "Today", seconds: 84),
        VoiceMemo(id: 2, title: "Melody for the chorus", date: "Yesterday", seconds: 38),
        VoiceMemo(id: 3, title: "Interview with Grandma, part 2", date: "Tuesday", seconds: 892),
        VoiceMemo(id: 4, title: "Notes after the client call", date: "Monday", seconds: 185),
        VoiceMemo(id: 5, title: "Birdsong at the allotment", date: "Sunday", seconds: 131),
        VoiceMemo(id: 6, title: "Shopping list", date: "Saturday", seconds: 19),
        VoiceMemo(id: 7, title: "Talk rehearsal, take 3", date: "10 Oct", seconds: 587),
        VoiceMemo(id: 8, title: "Parking: level 3, row F", date: "9 Oct", seconds: 6),
        VoiceMemo(id: 9, title: "Bedtime story", date: "7 Oct", seconds: 390),
        VoiceMemo(id: 10, title: "Podcast intro draft", date: "5 Oct", seconds: 72)
    ]
}
