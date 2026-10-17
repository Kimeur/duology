import SwiftUI

/// The start screen. One column that reads well on both displays.
struct HomeView: View {
    @Binding var setup: DuelSetup
    let onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text(AppInfo.name)
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("Two players, one phone. Each of you gets half the screen. Tap your targets. First to the goal wins.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("First to")
                            .font(.headline)
                        Picker("First to", selection: $setup.rules.goal) {
                            ForEach([5, 10, 20], id: \.self) { goal in
                                Text("\(goal) hits").tag(goal)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("home.goal")
                    }

                    Toggle(isOn: $setup.faceToFace) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Face to face")
                                .font(.headline)
                            Text("Turns player 1's half around, for a phone lying flat between you.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("home.faceToFace")
                }

                Button(action: onStart) {
                    Text("Start")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("home.start")
            }
            .frame(maxWidth: 520)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }
}
