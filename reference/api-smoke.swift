// api-smoke.swift
//
// Proves that the key iPhone Duo SwiftUI APIs in api-index.md exist with the
// spellings we document. It is not an app and has no @main. Typecheck it with:
//
//   DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer \
//   xcrun -sdk iphonesimulator swiftc -typecheck \
//   -target arm64-apple-ios27.1-simulator reference/api-smoke.swift
//
// Checked with Xcode 27.1 (27A9275), iOS 27.1 simulator SDK.

import SwiftUI

// MARK: - Arrangement: primary and secondary content that adapts to the display

@available(iOS 27.1, *)
struct SmokeArrangement: View {
    var body: some View {
        ArrangementView {
            Text("Primary")
                .splitArrangementLayoutRatio(0.6)
        } secondary: {
            SmokeSecondary()
                .splitArrangementLayoutSize(minWidth: 280, idealWidth: 360)
        }
        .arrangementViewStyle(.split.axes(.horizontal))
    }
}

@available(iOS 27.1, *)
struct SmokeOverlayArrangement: View {
    var body: some View {
        ArrangementView {
            Text("Map")
        } secondary: {
            SmokeSecondary()
                .overlayArrangementEdge(HorizontalEdge.trailing)
        }
        .arrangementViewStyle(.overlay)
    }
}

@available(iOS 27.1, *)
struct SmokeSecondary: View {
    @Environment(\.splitArrangementAxis) private var splitAxis
    @Environment(\.overlayArrangementZIndex) private var zIndex

    var body: some View {
        Text(splitAxis == .horizontal ? "Beside" : "Below or on top (z \(zIndex))")
    }
}

// MARK: - Reserved regions: keep controls out of the fold and the inner camera

@available(iOS 27.1, *)
struct SmokeReservedRegions: View {
    var body: some View {
        GeometryReader { proxy in
            let folds = proxy.reservedRegions(kind: .division)
            let cameras = proxy.reservedRegions(kind: .occlusion, options: .includeInactive)
            ZStack {
                ForEach(folds + cameras) { region in
                    Rectangle()
                        .fill(region.isActive ? .red.opacity(0.3) : .clear)
                        .frame(width: region.frame.width, height: region.frame.height)
                        .position(x: region.frame.midX, y: region.frame.midY)
                }
            }
        }
    }
}

// MARK: - Hinge: for effects only, never for layout

@available(iOS 27.1, *)
struct SmokeHinge: View {
    @State private var status = "No hinge"
    @State private var degrees = 0.0

    var body: some View {
        Text("\(status), \(Int(degrees)) degrees")
            .onHingeChange { _, newContext in
                guard let hinge = newContext.hinge else {
                    status = "No hinge"
                    return
                }
                degrees = hinge.angle.degrees
                if hinge.status == .closed {
                    status = "Closed"
                } else if hinge.status == .partiallyOpen {
                    status = "Partly open"
                } else if hinge.status == .fullyOpen {
                    status = "Open"
                }
            }
    }
}

// MARK: - Bars: vertical toolbars, tabs that become a sidebar

@available(iOS 27.1, *)
struct SmokeBars: View {
    @Environment(\.toolbarVerticalEdge) private var verticalEdge

    var body: some View {
        TabView {
            Tab("Library", systemImage: "books.vertical") {
                NavigationStack {
                    Text(verticalEdge == nil ? "Bars are horizontal" : "Bars are vertical")
                        // Container margins can differ per side next to a vertical bar.
                        .contentMargins(for: .container, edges: .horizontal)
                        .toolbar {
                            ToolbarItem(placement: .topBarPinnedTrailing) {
                                Button("Add", systemImage: "plus") {}
                            }
                            .axisBehavior(.verticalPreferred)
                            .visibilityPriority(.high)
                        }
                }
            }
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                Text("Search")
            }
        }
        // defaultTabBarPlacement only applies to the sidebarAdaptable style.
        .tabViewStyle(.sidebarAdaptable)
        .defaultTabBarPlacement(.sidebar)
        .toolbarVerticalCompressionBehavior(.prefersTabBar)
    }
}

@available(iOS 27.1, *)
struct SmokeVideoPlayerScreen: View {
    @State private var showInfo = false

    var body: some View {
        Color.black
            // A full-screen player is better served by horizontal bars.
            .toolbarVerticalBehavior(.disabled)
            .sheet(isPresented: $showInfo) {
                Text("Info")
                    .presentationPlacement(.trailing)
            }
    }
}

// MARK: - Scene accessory: content on the outer display during camera capture

@available(iOS 27.1, *)
struct SmokeCameraScreen: View {
    @State private var showPreviewOnOuter = true
    @State private var outerAvailable = false

    var body: some View {
        Text(outerAvailable ? "Outer display ready" : "Outer display not available")
            .sceneAccessory {
                CameraCaptureAccessory(isEnabled: $showPreviewOnOuter) {
                    Text("Smile")
                }
                .onAvailabilityChange { isAvailable in
                    outerAvailable = isAvailable
                }
            }
    }
}
