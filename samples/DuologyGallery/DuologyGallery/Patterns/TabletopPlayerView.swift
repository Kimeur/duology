import SwiftUI

/// Tabletop player: a nature film with one set of controls.
///
/// One layout in every pose (`FoldRegionsLayout`), so the film and its controls
/// keep their identity and playback never stops when the phone folds:
/// - Closed, and open flat: the controls float at the bottom of the film's
///   view. Closed, the picture moves up into the space above them; open, the
///   picture fills the width and they cover its bottom edge.
/// - Partly folded like a book: the film in the leading region, the controls
///   in the trailing region.
/// - Partly folded across and propped on a table (tabletop): the film above
///   the fold, the same controls below it.
///
/// The controls are the same view in every pose. Only their place changes.
/// Full-screen video is one of the cases where Apple suggests turning the
/// vertical bar off, as a fixed choice for the screen
/// (`toolbarVerticalBehavior(.disabled)`, iOS 27.1).
///
/// Skill: `duo-postures`, `references/tabletop-media.md`.
struct TabletopPlayerView: View {
    @State private var player = FilmPlayer(film: .kelpForest)
    @State private var fold = FoldGeometry()
    @State private var layoutSize = CGSize.zero
    @State private var controlsHeight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// True when the controls float over the film. Subtitles then sit above them.
    private var controlsOverlap: Bool {
        FoldRegionsLayout(fold: fold, unfolded: .overlay)
            .regions(in: CGRect(origin: .zero, size: layoutSize)) == nil
    }

    var body: some View {
        NavigationStack {
            FoldRegionsLayout(fold: fold, unfolded: .overlay) {
                // First: what people watch.
                FilmFrame(player: player, bottomInset: controlsOverlap ? controlsHeight : 0)
                // Second: what people touch. The same view in every pose.
                PlayerControls(player: player)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { controlsHeight = $0 }
            }
            // Read the fold on the layout itself, so its frame is in the layout's space.
            .onFoldChange { fold = $0 }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { layoutSize = $0 }
            // A short slide when the phone folds. With Reduce Motion the controls move at once.
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: fold)
            .background { Color.black.ignoresSafeArea() }
            .navigationTitle(player.film.series)
            .navigationBarTitleDisplayMode(.inline)
            .galleryCloseButton()
            .horizontalBarsForVideo()
        }
        .preferredColorScheme(.dark)
        // Also on the presentation's root: the gallery shows this screen as a
        // full-screen cover, and the bar choice is read per presentation.
        .horizontalBarsForVideo()
        // Attached above the layout, so a fold never restarts playback.
        .task(id: player.isPlaying) { await player.run() }
    }
}

private extension View {
    /// A fixed choice for this screen: the bar stays horizontal so the film gets
    /// the full width. Never toggled from view state.
    @ViewBuilder
    func horizontalBarsForVideo() -> some View {
        if #available(iOS 27.1, *) {
            toolbarVerticalBehavior(.disabled)
        } else {
            self
        }
    }
}

// MARK: - Model

/// Playback state for the screen. It lives above the layout, so a fold, an
/// unfold or a rotation never resets the position, the speed or the subtitles.
@Observable
final class FilmPlayer {
    let film: Film
    var isPlaying = false
    /// Seconds into the film.
    var position: Double
    var rate: Double = 1
    var showsSubtitles = true

    init(film: Film) {
        self.film = film
        position = film.resumePosition
    }

    var chapter: Film.Chapter {
        film.chapters.last { $0.start <= position } ?? film.chapters[0]
    }

    var subtitle: String? {
        guard showsSubtitles else { return nil }
        return film.subtitles.first { $0.start <= position && position < $0.end }?.text
    }

    func togglePlayback() {
        if position >= film.duration { position = 0 }
        isPlaying.toggle()
    }

    func skip(by seconds: Double) {
        position = min(film.duration, max(0, position + seconds))
    }

    /// Moves the playhead while playing. The sample has no video file, so the
    /// film is drawn and this clock stands in for the player's.
    func run() async {
        let tick = 0.05
        while isPlaying, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(tick))
            guard isPlaying else { return }
            position = min(film.duration, position + tick * rate)
            if position >= film.duration { isPlaying = false }
        }
    }
}

// MARK: - The film

/// The picture: a kelp forest, drawn in 16:9 and fitted to the region it gets.
/// Subtitles sit inside the picture, and above the controls when those float over it.
private struct FilmFrame: View {
    let player: FilmPlayer
    /// How much of this view's bottom edge the floating controls cover.
    let bottomInset: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let picture = Self.place(aspect: 16 / 9, in: proxy.size, above: bottomInset)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    KelpForestPainter(time: player.position).draw(in: &context, rect: picture)
                }
                .accessibilityLabel("Film: \(player.film.title)")

                if let line = player.subtitle {
                    // The line's bottom edge: inside the picture, and above floating controls.
                    let bottom = max(0, min(picture.maxY - 14, proxy.size.height - bottomInset - 14))
                    Text(line)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .frame(width: max(0, picture.width - 32), height: bottom, alignment: .bottom)
                        .position(x: picture.midX, y: bottom / 2)
                        .accessibilityLabel("Subtitle: \(line)")
                }
            }
        }
    }

    /// The picture's frame: centred in the space above floating controls when it
    /// fits there whole (the closed phone, held upright), else centred in the view.
    static func place(aspect: CGFloat, in size: CGSize, above bottomInset: CGFloat) -> CGRect {
        let picture = fit(aspect: aspect, in: size)
        let free = size.height - bottomInset
        guard bottomInset > 0, picture.height <= free else { return picture }
        return picture.offsetBy(dx: 0, dy: (free - picture.height) / 2 - picture.minY)
    }

    /// The largest rectangle of `aspect` (width over height) that fits, centred.
    static func fit(aspect: CGFloat, in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        var width = size.width
        var height = width / aspect
        if height > size.height {
            height = size.height
            width = height * aspect
        }
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }
}

/// Draws one frame of the kelp forest at a point in the film. Paused, the frame holds still.
private struct KelpForestPainter {
    let time: Double

    func draw(in context: inout GraphicsContext, rect r: CGRect) {
        guard r.width > 1 else { return }
        context.clip(to: Path(r))

        // Water: lighter near the surface.
        context.fill(Path(r), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x2A9BB8), Color(hex: 0x0C5A74), Color(hex: 0x062C3D)]),
            startPoint: CGPoint(x: r.midX, y: r.minY), endPoint: CGPoint(x: r.midX, y: r.maxY)))

        // Sunlight from the surface.
        for index in 0..<5 {
            let drift = sin(time * 0.15 + Double(index)) * r.width * 0.01
            let x = r.minX + r.width * (0.12 + 0.19 * CGFloat(index)) + drift
            var ray = Path()
            ray.move(to: CGPoint(x: x - r.width * 0.025, y: r.minY))
            ray.addLine(to: CGPoint(x: x + r.width * 0.025, y: r.minY))
            ray.addLine(to: CGPoint(x: x + r.width * 0.16, y: r.maxY))
            ray.addLine(to: CGPoint(x: x + r.width * 0.06, y: r.maxY))
            ray.closeSubpath()
            context.fill(ray, with: .linearGradient(
                Gradient(colors: [.white.opacity(0.16), .white.opacity(0)]),
                startPoint: CGPoint(x: x, y: r.minY), endPoint: CGPoint(x: x, y: r.maxY * 0.85)))
        }

        // Kelp far away: thin and faded.
        for index in 0..<8 {
            let x = r.minX + r.width * (0.04 + 0.13 * CGFloat(index))
            strand(in: &context, rect: r, baseX: x, topY: r.minY + r.height * 0.02,
                   width: r.width * 0.007, color: Color(hex: 0x3D5A3A).opacity(0.55),
                   phase: Double(index) * 1.7, blades: false)
        }

        // The sea floor.
        var floor = Path()
        floor.move(to: CGPoint(x: r.minX, y: r.maxY))
        floor.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.84))
        floor.addCurve(to: CGPoint(x: r.minX + r.width * 0.38, y: r.minY + r.height * 0.88),
                       control1: CGPoint(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.76),
                       control2: CGPoint(x: r.minX + r.width * 0.25, y: r.minY + r.height * 0.92))
        floor.addCurve(to: CGPoint(x: r.minX + r.width * 0.72, y: r.minY + r.height * 0.80),
                       control1: CGPoint(x: r.minX + r.width * 0.50, y: r.minY + r.height * 0.84),
                       control2: CGPoint(x: r.minX + r.width * 0.58, y: r.minY + r.height * 0.74))
        floor.addCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.86),
                       control1: CGPoint(x: r.minX + r.width * 0.84, y: r.minY + r.height * 0.86),
                       control2: CGPoint(x: r.minX + r.width * 0.92, y: r.minY + r.height * 0.82))
        floor.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        floor.closeSubpath()
        context.fill(floor, with: .linearGradient(
            Gradient(colors: [Color(hex: 0x16313A), Color(hex: 0x081820)]),
            startPoint: CGPoint(x: r.midX, y: r.minY + r.height * 0.75), endPoint: CGPoint(x: r.midX, y: r.maxY)))

        // A school of small fish, high up.
        for index in 0..<16 {
            let row = CGFloat(index % 4), column = CGFloat(index / 4)
            let swim = CGFloat((time * 0.02).truncatingRemainder(dividingBy: 1)) * r.width * 0.3
            let x = r.minX + r.width * (0.56 + 0.035 * column + 0.012 * row) + swim
            let y = r.minY + r.height * (0.18 + 0.035 * row + 0.01 * column)
            let length = r.width * 0.016
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: length, height: length * 0.38)),
                         with: .color(Color(hex: 0xCFE6EE).opacity(0.7)))
        }

        // Kelp close by: golden brown, with blades.
        let near: [(CGFloat, Double)] = [(0.10, 0.4), (0.24, 2.1), (0.43, 4.0), (0.80, 1.2), (0.93, 3.3)]
        for (index, item) in near.enumerated() {
            strand(in: &context, rect: r, baseX: r.minX + r.width * item.0,
                   topY: r.minY - r.height * 0.05, width: r.width * 0.011,
                   color: Color(hex: index.isMultiple(of: 2) ? 0x8C6A1C : 0x7A5C18),
                   phase: item.1, blades: true)
        }

        // Two garibaldi: bright orange, guarding their rocks.
        fish(in: &context, at: CGPoint(x: r.minX + r.width * 0.62, y: r.minY + r.height * 0.64),
             length: r.width * 0.085, facingLeft: true, color: Color(hex: 0xF26A1B))
        fish(in: &context, at: CGPoint(x: r.minX + r.width * 0.33, y: r.minY + r.height * 0.56),
             length: r.width * 0.05, facingLeft: false, color: Color(hex: 0xE0601A).opacity(0.8))

        // Bubbles rising.
        for index in 0..<9 {
            let seed = Double(index) * 0.137
            let rise = (time * 0.05 + seed * 3).truncatingRemainder(dividingBy: 1)
            let x = r.minX + r.width * CGFloat(0.2 + (seed * 5).truncatingRemainder(dividingBy: 0.7))
            let y = r.maxY - r.height * CGFloat(rise)
            let size = r.width * CGFloat(0.006 + 0.004 * (seed * 7).truncatingRemainder(dividingBy: 1))
            context.stroke(Path(ellipseIn: CGRect(x: x, y: y, width: size, height: size)),
                           with: .color(.white.opacity(0.35)), lineWidth: 1)
        }

        // Darker corners, like a lens underwater.
        context.fill(Path(r), with: .radialGradient(
            Gradient(colors: [.clear, .black.opacity(0.45)]),
            center: CGPoint(x: r.midX, y: r.midY), startRadius: r.width * 0.25, endRadius: r.width * 0.7))
    }

    /// One kelp stalk from the floor to near the surface, swaying with the swell.
    private func strand(in context: inout GraphicsContext, rect r: CGRect, baseX: CGFloat, topY: CGFloat,
                        width: CGFloat, color: Color, phase: Double, blades: Bool) {
        let floorY = r.maxY
        let sway = CGFloat(sin(time * 0.6 + phase)) * r.width * 0.02
        var points: [CGPoint] = []
        for step in 0...24 {
            let t = CGFloat(step) / 24
            let wiggle = CGFloat(sin(Double(t) * 4.2 + phase)) * r.width * 0.012 * t
            points.append(CGPoint(x: baseX + wiggle + sway * t * t, y: floorY - (floorY - topY) * t))
        }
        var stalk = Path()
        stalk.addLines(points)
        context.stroke(stalk, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))

        guard blades else { return }
        for step in stride(from: 3, to: points.count - 1, by: 2) {
            let point = points[step]
            let side: CGFloat = step.isMultiple(of: 4) ? 1 : -1
            var blade = context
            blade.translateBy(x: point.x, y: point.y)
            blade.rotate(by: .degrees(Double(side) * (38 + 8 * sin(time * 0.8 + phase + Double(step)))))
            let length = r.width * 0.055
            blade.fill(Path(ellipseIn: CGRect(x: 0, y: -length, width: width * 1.6, height: length)),
                       with: .color(color.opacity(0.9)))
            // The gas bladder that holds the blade up.
            blade.fill(Path(ellipseIn: CGRect(x: -width * 0.1, y: -width * 1.4, width: width * 1.4, height: width * 1.4)),
                       with: .color(Color(hex: 0xB89434)))
        }
    }

    private func fish(in context: inout GraphicsContext, at center: CGPoint, length: CGFloat,
                      facingLeft: Bool, color: Color) {
        var fish = context
        fish.translateBy(x: center.x, y: center.y + CGFloat(sin(time * 1.3)) * length * 0.04)
        if !facingLeft { fish.scaleBy(x: -1, y: 1) }
        let body = CGRect(x: -length / 2, y: -length * 0.3, width: length * 0.8, height: length * 0.6)
        var tail = Path()
        tail.move(to: CGPoint(x: length * 0.25, y: 0))
        tail.addLine(to: CGPoint(x: length * 0.52, y: -length * 0.22))
        tail.addLine(to: CGPoint(x: length * 0.48, y: 0))
        tail.addLine(to: CGPoint(x: length * 0.52, y: length * 0.22))
        tail.closeSubpath()
        fish.fill(tail, with: .color(color))
        fish.fill(Path(ellipseIn: body), with: .color(color))
        fish.fill(Path(ellipseIn: CGRect(x: -length * 0.36, y: -length * 0.1, width: length * 0.08, height: length * 0.08)),
                  with: .color(.black.opacity(0.75)))
    }
}

// MARK: - Controls

/// One set of controls for every pose: title, chapters, scrubber, transport,
/// subtitles and speed. Every control has a title for VoiceOver and Voice
/// Control, and a hit region of at least 44 × 44 pt.
private struct PlayerControls: View {
    @Bindable var player: FilmPlayer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.film.title)
                        .font(.headline)
                    Text("\(player.film.episode) · \(player.chapter.title)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.identity)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                chapterMenu
            }

            VStack(spacing: 2) {
                Slider(value: $player.position, in: 0...player.film.duration) {
                    Text("Playback Position")
                }
                .tint(.white)
                HStack {
                    Text(Self.clock(player.position))
                    Spacer()
                    Text("−" + Self.clock(player.film.duration - player.position))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            }

            HStack(spacing: 0) {
                Button(player.showsSubtitles ? "Hide Subtitles" : "Show Subtitles",
                       systemImage: player.showsSubtitles ? "captions.bubble.fill" : "captions.bubble") {
                    player.showsSubtitles.toggle()
                }
                .duoTouchTarget()
                Spacer(minLength: 8)
                Button("Back 10 Seconds", systemImage: "gobackward.10") { player.skip(by: -10) }
                    .duoTouchTarget()
                Button(player.isPlaying ? "Pause" : "Play", systemImage: player.isPlaying ? "pause.fill" : "play.fill") {
                    player.togglePlayback()
                }
                .font(.title)
                .foregroundStyle(.black)
                .frame(width: 64, height: 64)
                .background(.white, in: Circle())
                .contentShape(Circle())
                .padding(.horizontal, 18)
                Button("Forward 10 Seconds", systemImage: "goforward.10") { player.skip(by: 10) }
                    .duoTouchTarget()
                Spacer(minLength: 8)
                speedMenu
            }
            .labelStyle(.iconOnly)
            .font(.title2)
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: 520)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .padding(16)
    }

    private var chapterMenu: some View {
        Menu {
            Picker("Chapter", selection: Binding(
                get: { player.chapter.start },
                set: { player.position = $0 })) {
                ForEach(player.film.chapters) { chapter in
                    Text("\(chapter.title)  \(Self.clock(chapter.start))").tag(chapter.start)
                }
            }
        } label: {
            Label("Chapters", systemImage: "list.bullet")
                .labelStyle(.iconOnly)
                .font(.title3)
                .duoTouchTarget()
        }
    }

    private var speedMenu: some View {
        Menu {
            Picker("Playback Speed", selection: $player.rate) {
                ForEach([0.5, 1, 1.25, 1.5, 2], id: \.self) { rate in
                    Text(Self.rateLabel(rate)).tag(rate)
                }
            }
        } label: {
            Text(Self.rateLabel(player.rate))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .duoTouchTarget()
        }
        .accessibilityLabel("Playback Speed, \(Self.rateLabel(player.rate))")
    }

    static func clock(_ seconds: Double) -> String {
        Duration.seconds(max(0, seconds.rounded(.down))).formatted(.time(pattern: .minuteSecond))
    }

    static func rateLabel(_ rate: Double) -> String {
        rate.formatted(.number.precision(.fractionLength(0...2))) + "×"
    }
}

// MARK: - Sample film

/// A made-up nature series. The facts in the subtitles are general knowledge
/// about giant kelp forests.
struct Film {
    struct Chapter: Identifiable {
        let start: Double
        let title: String
        var id: Double { start }
    }

    struct Subtitle {
        let start: Double
        let end: Double
        let text: String
    }

    let title: String
    let series: String
    let episode: String
    let duration: Double
    /// Where the viewer stopped last time.
    let resumePosition: Double
    let chapters: [Chapter]
    let subtitles: [Subtitle]

    static let kelpForest: Film = {
        let lines = [
            "Giant kelp can grow half a metre in a single day.",
            "Gas-filled bladders hold each blade up towards the light.",
            "Below the canopy, a garibaldi guards its patch of rock.",
            "It will even face down a diver to defend it.",
            "Each spring the male clears a nest and waits for a visitor.",
            "Higher up, a school of topsmelt turns as one.",
            "The canopy shades the floor like a forest on land.",
            "Sea urchins graze here at night, and otters hunt them.",
            "Where the otters vanished, the urchins took the forest.",
            "Where they returned, the kelp came back within years."
        ]
        let first = 1_018.0
        let subtitles = lines.enumerated().map { index, text in
            Subtitle(start: first + Double(index) * 8, end: first + Double(index) * 8 + 7, text: text)
        }
        return Film(
            title: "The Kelp Forest",
            series: "Tidelines",
            episode: "Episode 3",
            duration: 42 * 60 + 16,
            resumePosition: 1_029,
            chapters: [
                Chapter(start: 0, title: "Low water"),
                Chapter(start: 580, title: "Into the canopy"),
                Chapter(start: 1_275, title: "The night shift"),
                Chapter(start: 2_030, title: "Storm season")
            ],
            subtitles: subtitles)
    }()
}
