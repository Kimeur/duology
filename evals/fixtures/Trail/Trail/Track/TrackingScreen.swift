import SwiftUI

struct TrackingScreen: View {
    @StateObject private var recorder = Recorder()

    var body: some View {
        ZStack {
            TrailMap(followsLocation: recorder.followsLocation)
                .ignoresSafeArea()
            VStack {
                Spacer()
                StatsPanel(recorder: recorder)
            }
        }
        .overlay(alignment: .top) {
            HStack(spacing: 20) {
                SmallRoundButton(title: "Locate", symbol: "location.fill") {
                    recorder.followsLocation.toggle()
                }
                .accessibilityIdentifier("track.locate")
                SmallRoundButton(title: recorder.isRecording ? "Stop" : "Record",
                                 symbol: recorder.isRecording ? "stop.fill" : "record.circle",
                                 tint: .red) {
                    recorder.toggleRecording()
                }
                .accessibilityIdentifier("track.record")
                SmallRoundButton(title: "Lap", symbol: "flag.fill") {
                    recorder.addLap()
                }
                .accessibilityIdentifier("track.lap")
            }
            .padding(10)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, 8)
        }
    }
}

struct SmallRoundButton: View {
    let title: String
    let symbol: String
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(.background))
        }
        .accessibilityLabel(title)
    }
}

struct StatsPanel: View {
    @ObservedObject var recorder: Recorder

    var body: some View {
        HStack(spacing: 0) {
            stat("Distance", recorder.distanceText)
            Divider().frame(maxHeight: 40)
            stat("Time", recorder.timeText)
            Divider().frame(maxHeight: 40)
            stat("Pace", recorder.paceText)
        }
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding()
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().bold())
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A drawn stand-in for the map, with the walked route.
struct TrailMap: View {
    let followsLocation: Bool

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.84, green: 0.90, blue: 0.80)))
            var route = Path()
            route.move(to: CGPoint(x: size.width * 0.1, y: size.height * 0.8))
            route.addCurve(to: CGPoint(x: size.width * 0.85, y: size.height * 0.25),
                           control1: CGPoint(x: size.width * 0.4, y: size.height * 0.9),
                           control2: CGPoint(x: size.width * 0.5, y: size.height * 0.1))
            context.stroke(route, with: .color(.orange), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }
        .overlay {
            Image(systemName: followsLocation ? "location.circle.fill" : "location.circle")
                .font(.largeTitle)
                .foregroundStyle(.blue)
        }
        .accessibilityLabel("Map of the route")
    }
}
