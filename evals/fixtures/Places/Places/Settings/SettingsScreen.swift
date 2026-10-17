import SwiftUI

struct SettingsScreen: View {
    @AppStorage("units") private var metric = true
    @AppStorage("showVisited") private var showVisited = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    Toggle("Metric units", isOn: $metric)
                    Toggle("Show visited places", isOn: $showVisited)
                }
                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Device", value: Diagnostics.deviceSummary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
