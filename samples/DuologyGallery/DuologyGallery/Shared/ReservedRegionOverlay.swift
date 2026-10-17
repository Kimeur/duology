import SwiftUI

/// Draws every reserved region over the screen: the fold (division) and the
/// cameras and status bar corner (occlusion). Inactive regions are dashed.
///
/// Turn it on from the gallery's home screen, or launch with `-showsRegions YES`.
/// It never takes touches, so the pattern under it works as usual.
struct ReservedRegionOverlay: View {
    var body: some View {
        if #available(iOS 27.1, *) {
            RegionDrawing()
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

@available(iOS 27.1, *)
private struct RegionDrawing: View {
    @State private var regions: [ReservedRegion] = []
    @State private var size = CGSize.zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(regions) { region in
                RegionMark(region: region)
                    .frame(width: max(region.frame.width, 1), height: max(region.frame.height, 1))
                    .offset(x: region.frame.minX, y: region.frame.minY)
            }
        }
        // One legend, away from the regions: the status bar and the vertical
        // bars draw over the app, so labels next to a region get covered.
        .overlay(alignment: .bottomLeading) {
            RegionLegend(regions: regions, size: size)
                .padding(.leading, 16)
                .padding(.bottom, 44)
        }
        // Region frames come back in this view's space. Read them on every
        // geometry change: the first read in onAppear can be empty.
        .onGeometryChange(for: [ReservedRegion].self) { proxy in
            proxy.reservedRegions(kind: .division, options: .includeInactive)
                + proxy.reservedRegions(kind: .occlusion, options: .includeInactive)
        } action: { newRegions in
            regions = newRegions
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
    }
}

@available(iOS 27.1, *)
private struct RegionMark: View {
    let region: ReservedRegion

    private var isFold: Bool { region.kind == .division }
    private var tint: Color { isFold ? .pink : .orange }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        ZStack {
            shape.fill(tint.opacity(region.isActive ? 0.22 : 0.08))
            shape.strokeBorder(tint, style: StrokeStyle(lineWidth: 1.5, dash: region.isActive ? [] : [5, 4]))
            // The area the hardware covers, without the margins Apple adds for touch.
            let margins = region.margins
            Rectangle()
                .fill(tint.opacity(0.4))
                .frame(width: max(1, region.frame.width - margins.leading - margins.trailing),
                       height: max(1, region.frame.height - margins.top - margins.bottom))
        }
    }
}

/// Lists each region with its kind, state and frame in points.
@available(iOS 27.1, *)
private struct RegionLegend: View {
    let regions: [ReservedRegion]
    let size: CGSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // This overlay ignores the safe area, so its size is the window's.
            Text("Window \(Int(size.width)) × \(Int(size.height)) pt")
            if regions.isEmpty {
                Text("No reserved regions")
            }
            ForEach(regions) { region in
                let isFold = region.kind == .division
                let frame = region.frame
                HStack(spacing: 6) {
                    Circle().fill(isFold ? Color.pink : Color.orange).frame(width: 8, height: 8)
                    Text("\(isFold ? "Fold" : "Occlusion"), \(region.isActive ? "active" : "inactive"): "
                         + "\(Int(frame.width)) × \(Int(frame.height)) at \(Int(frame.minX)), \(Int(frame.minY))")
                }
            }
        }
        .font(.caption2.monospacedDigit().weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
