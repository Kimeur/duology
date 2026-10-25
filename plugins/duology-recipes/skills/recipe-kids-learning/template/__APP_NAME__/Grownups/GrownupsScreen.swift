import SwiftUI

/// The grown-ups area, reached only through the parental gate: the stars so far, the
/// read-aloud setting, Reset Progress, what the app does with data, and the privacy
/// policy. This is the only file in the app that can open a link.
struct GrownupsScreen: View {
    let store: LearningStore

    @Environment(\.openURL) private var openURL
    @State private var confirmsReset = false

    private var totalQuestions: Int { store.activities.reduce(0) { $0 + $1.questions.count } }

    var body: some View {
        @Bindable var store = store
        Form {
            Section("Progress") {
                LabeledContent("Stars", value: "\(store.progress.stars) of \(totalQuestions)")
                    .accessibilityIdentifier("grownups.stars")
                Toggle("Speak questions and feedback", isOn: $store.readsAloud)
                    .accessibilityIdentifier("grownups.readAloud")
                Button("Reset Progress…", role: .destructive) { confirmsReset = true }
                    .accessibilityIdentifier("grownups.reset")
            }
            Section("What this app does with data") {
                Text("The stars, the question each activity is on and the speech setting are saved on this iPhone, in this app's own storage. Nothing else is saved.")
                Text("The app has no account, no ads, no analytics and no tracking. It never connects to the internet, so nothing your child does leaves this device.")
                Text("Deleting the app deletes its progress. Reset Progress clears it now.")
                Button {
                    openURL(AppFacts.privacyPolicy)
                } label: {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                }
                .accessibilityHint("Opens in Safari")
                .accessibilityIdentifier("grownups.privacy")
            }
        }
        .navigationTitle("Grown-ups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { store.closeGate() }
                    .accessibilityIdentifier("grownups.done")
            }
        }
        .confirmationDialog("Reset all stars?", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("Reset All Stars", role: .destructive) { store.resetProgress() }
        } message: {
            Text("Every activity goes back to its first question. This can't be undone.")
        }
        .testMarker("grownups.state", value: "stars=\(store.progress.stars)|readsAloud=\(store.readsAloud ? 1 : 0)|")
    }
}
