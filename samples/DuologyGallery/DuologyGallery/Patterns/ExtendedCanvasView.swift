import SwiftUI

/// Extended canvas: a trail map you can pan and sketch on.
///
/// The map fills the window and runs across the fold, under the side bars too.
/// Only the tools move: bottom centre when closed or flat, the trailing region
/// when folded like a book, the bottom region when folded across. The clear
/// dialog is a system dialog, so it avoids the fold on its own.
///
/// Pattern guide: `duo-patterns/references/extended-canvas.md`.
struct ExtendedCanvasView: View {
    enum Tool: String, CaseIterable {
        case pan = "Pan"
        case draw = "Sketch"

        var symbol: String {
            switch self {
            case .pan: "hand.raised"
            case .draw: "pencil"
            }
        }
    }

    @State private var tool = Tool.pan
    @State private var offset = CGSize.zero
    @State private var dragStart: CGSize?
    @State private var isSketching = false
    @State private var sketches: [[CGPoint]] = []
    @State private var viewSize = CGSize.zero
    @State private var hasCentred = false
    @State private var fold = FoldGeometry()
    @State private var confirmsClear = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                // The canvas is the scrolling content: it fills everything and never displaces.
                TrailMapCanvas(offset: offset, sketches: sketches, dark: colorScheme == .dark)
                    .ignoresSafeArea()
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                        viewSize = size
                        if !hasCentred, size.width > 0 {
                            hasCentred = true
                            recentre()
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(dragGesture)
                    .accessibilityLabel("Trail map")
                    .accessibilityHint(tool == .pan ? "Drag to move the map" : "Drag to sketch a route")

                GeometryReader { proxy in
                    let region = controlRegion(in: proxy.size, fold: fold)
                    ZStack {
                        RouteCard()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(16)
                        // Interactive, so it never sits on the fold.
                        ToolPalette(tool: $tool, canUndo: !sketches.isEmpty,
                                    onUndo: { sketches.removeLast() },
                                    onClear: { confirmsClear = true },
                                    onRecentre: recentre)
                            .frame(width: region.width, height: region.height, alignment: .bottom)
                            .position(x: region.midX, y: region.midY)
                    }
                }
                .onFoldChange { fold = $0 }
            }
            .animation(.smooth, value: fold)
            .confirmationDialog("Clear your sketches?", isPresented: $confirmsClear, titleVisibility: .visible) {
                Button("Clear Sketches", role: .destructive) { sketches.removeAll() }
            }
            .navigationTitle("Trail Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .galleryCloseButton()
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                switch tool {
                case .pan:
                    let start = dragStart ?? offset
                    dragStart = start
                    offset = CGSize(width: start.width + value.translation.width,
                                    height: start.height + value.translation.height)
                case .draw:
                    let point = CGPoint(x: value.location.x - offset.width, y: value.location.y - offset.height)
                    if isSketching, !sketches.isEmpty {
                        sketches[sketches.count - 1].append(point)
                    } else {
                        isSketching = true
                        sketches.append([point])
                    }
                }
            }
            .onEnded { _ in
                dragStart = nil
                isSketching = false
            }
    }

    /// Puts the summit in the middle of the view.
    private func recentre() {
        withAnimation(.smooth) {
            offset = CGSize(width: viewSize.width / 2 - TrailMap.summit.x,
                            height: viewSize.height / 2 - TrailMap.summit.y)
        }
    }
}

// MARK: - Tools

private struct ToolPalette: View {
    @Binding var tool: ExtendedCanvasView.Tool
    var canUndo: Bool
    var onUndo: () -> Void
    var onClear: () -> Void
    var onRecentre: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ExtendedCanvasView.Tool.allCases, id: \.self) { item in
                Button(item.rawValue, systemImage: item.symbol) { tool = item }
                    .buttonStyle(PaletteButtonStyle(isSelected: tool == item))
                    .accessibilityAddTraits(tool == item ? .isSelected : [])
            }
            Divider().frame(height: 24).padding(.horizontal, 4)
            Button("Undo", systemImage: "arrow.uturn.backward", action: onUndo)
                .buttonStyle(PaletteButtonStyle(isSelected: false))
                .disabled(!canUndo)
            Button("Clear", systemImage: "trash", action: onClear)
                .buttonStyle(PaletteButtonStyle(isSelected: false))
                .disabled(!canUndo)
            Button("Recentre", systemImage: "scope", action: onRecentre)
                .buttonStyle(PaletteButtonStyle(isSelected: false))
        }
        .labelStyle(.iconOnly)
        .padding(6)
        .glassEffect(.regular, in: Capsule())
        .padding(.bottom, 16)
    }
}

private struct PaletteButtonStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(width: 44, height: 44)
            .background {
                if isSelected {
                    Circle().fill(Color(hex: 0x3F7D20))
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.35)
            .contentShape(Circle())
    }
}

private struct RouteCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ridge Loop")
                .font(.headline)
            HStack(spacing: 12) {
                Label("11.4 km", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                Label("620 m", systemImage: "arrow.up.right")
                Label("5 h", systemImage: "clock")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Capsule().fill(.primary).frame(width: 60, height: 3)
                Text("500 m").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - The map

/// Shapes of the sample trail map, in map coordinates. Built once.
private enum TrailMap {
    static let size = CGSize(width: 1800, height: 1250)
    static let summit = CGPoint(x: 1150, y: 430)

    struct Peak {
        var center: CGPoint
        var rings: Int
        var phase: Double
        var label: String
    }

    static let peaks = [
        Peak(center: CGPoint(x: 1150, y: 430), rings: 10, phase: 0.4, label: "High Cairn 2,140 m"),
        Peak(center: CGPoint(x: 520, y: 830), rings: 8, phase: 1.7, label: "Grey Knoll 1,680 m"),
        Peak(center: CGPoint(x: 1580, y: 980), rings: 6, phase: 2.9, label: "Black Crag 1,320 m")
    ]

    /// Contour rings for every peak, inner rings last.
    static let contours: [(path: Path, level: Int, isIndex: Bool)] = peaks.flatMap { peak in
        (1...peak.rings).reversed().map { ring in
            (contour(around: peak.center, radius: CGFloat(ring) * 30, phase: peak.phase + Double(ring) * 0.12),
             peak.rings - ring, ring % 5 == 0)
        }
    }

    static func contour(around center: CGPoint, radius: CGFloat, phase: Double) -> Path {
        var path = Path()
        let steps = 96
        for step in 0...steps {
            let angle = Double(step) / Double(steps) * 2 * .pi
            let wobble = 1 + 0.12 * sin(3 * angle + phase) + 0.07 * sin(5 * angle + phase * 2) + 0.04 * sin(7 * angle)
            let point = CGPoint(x: center.x + CGFloat(cos(angle) * wobble) * radius * 1.3,
                                y: center.y + CGFloat(sin(angle) * wobble) * radius)
            step == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    static let lake: Path = contour(around: CGPoint(x: 290, y: 320), radius: 70, phase: 2.2)

    static let river: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 330, y: 400))
        path.addCurve(to: CGPoint(x: 150, y: 760), control1: CGPoint(x: 360, y: 520), control2: CGPoint(x: 120, y: 600))
        path.addCurve(to: CGPoint(x: 60, y: 1250), control1: CGPoint(x: 190, y: 930), control2: CGPoint(x: 40, y: 1050))
        return path
    }()

    static let trailPoints: [CGPoint] = [
        CGPoint(x: 180, y: 1110), CGPoint(x: 330, y: 1060), CGPoint(x: 520, y: 1110), CGPoint(x: 730, y: 1030),
        CGPoint(x: 830, y: 880), CGPoint(x: 880, y: 740), CGPoint(x: 950, y: 640), CGPoint(x: 1060, y: 560),
        CGPoint(x: 1150, y: 430), CGPoint(x: 1270, y: 520), CGPoint(x: 1390, y: 610), CGPoint(x: 1500, y: 700),
        CGPoint(x: 1650, y: 760)
    ]

    /// A smooth path through the trail points (Catmull-Rom as cubic curves).
    static let trail: Path = {
        var path = Path()
        let points = trailPoints
        path.move(to: points[0])
        for index in 0..<(points.count - 1) {
            let p0 = points[max(index - 1, 0)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(index + 2, points.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }()

    static let waypoints: [(point: CGPoint, name: String, symbol: String)] = [
        (CGPoint(x: 180, y: 1110), "Trailhead", "figure.hiking"),
        (CGPoint(x: 950, y: 640), "Ridge camp", "tent.fill"),
        (CGPoint(x: 1150, y: 430), "Summit, 2,140 m", "flag.fill"),
        (CGPoint(x: 1650, y: 760), "Bothy", "house.fill")
    ]
}

private struct TrailMapCanvas: View {
    let offset: CGSize
    let sketches: [[CGPoint]]
    let dark: Bool

    var body: some View {
        Canvas { context, size in
            let ground = dark ? Color(hex: 0x17221B) : Color(hex: 0xE3EDDC)
            let line = dark ? Color(hex: 0x7FA36A) : Color(hex: 0x6E8B4E)
            let water = dark ? Color(hex: 0x1F4E6E) : Color(hex: 0xA7D0EE)
            let rise = dark ? Color(hex: 0x9CC27F) : Color(hex: 0x4E7A2C)

            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(ground))
            context.translateBy(x: offset.width, y: offset.height)

            // Grid, so panning reads as movement even over flat ground.
            var grid = Path()
            for x in stride(from: 0.0, through: TrailMap.size.width, by: 150) {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: TrailMap.size.height))
            }
            for y in stride(from: 0.0, through: TrailMap.size.height, by: 150) {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: TrailMap.size.width, y: y))
            }
            context.stroke(grid, with: .color(line.opacity(0.12)), lineWidth: 1)

            // Contours, filled a little darker towards each summit.
            for contour in TrailMap.contours {
                context.fill(contour.path, with: .color(rise.opacity(0.045)))
                context.stroke(contour.path, with: .color(line.opacity(contour.isIndex ? 0.75 : 0.45)),
                               lineWidth: contour.isIndex ? 1.6 : 0.9)
            }

            context.stroke(TrailMap.river, with: .color(water), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            context.fill(TrailMap.lake, with: .color(water))
            context.draw(Text("Mirror Tarn").font(.caption.weight(.medium)).foregroundStyle(dark ? .white.opacity(0.7) : Color(hex: 0x1F4E6E)),
                         at: CGPoint(x: 290, y: 320))

            for peak in TrailMap.peaks where !TrailMap.waypoints.contains(where: { $0.point == peak.center }) {
                var marker = Path()
                marker.move(to: CGPoint(x: peak.center.x, y: peak.center.y - 7))
                marker.addLine(to: CGPoint(x: peak.center.x + 7, y: peak.center.y + 5))
                marker.addLine(to: CGPoint(x: peak.center.x - 7, y: peak.center.y + 5))
                marker.closeSubpath()
                context.fill(marker, with: .color(dark ? .white : Color(hex: 0x2F3B2A)))
                context.draw(Text(peak.label).font(.caption2.weight(.semibold)).foregroundStyle(dark ? .white : Color(hex: 0x2F3B2A)),
                             at: CGPoint(x: peak.center.x, y: peak.center.y + 18))
            }

            // The trail: a halo, then the dashed line.
            context.stroke(TrailMap.trail, with: .color(.white.opacity(dark ? 0.25 : 0.8)),
                           style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            context.stroke(TrailMap.trail, with: .color(Color(hex: 0xE4572E)),
                           style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [10, 7]))

            for waypoint in TrailMap.waypoints {
                let disc = Path(ellipseIn: CGRect(x: waypoint.point.x - 15, y: waypoint.point.y - 15, width: 30, height: 30))
                context.fill(disc, with: .color(.white))
                context.stroke(disc, with: .color(Color(hex: 0xE4572E)), lineWidth: 3)
                context.draw(Image(systemName: waypoint.symbol), in: CGRect(x: waypoint.point.x - 8, y: waypoint.point.y - 8, width: 16, height: 16))
                context.draw(Text(waypoint.name).font(.caption.weight(.bold)).foregroundStyle(dark ? .white : .black),
                             at: CGPoint(x: waypoint.point.x, y: waypoint.point.y - 26))
            }

            // The person's own sketches go on top.
            for sketch in sketches where sketch.count > 1 {
                var path = Path()
                path.addLines(sketch)
                context.stroke(path, with: .color(Color(hex: 0x2B55C7)),
                               style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
