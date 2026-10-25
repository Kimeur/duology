import SwiftUI

/// The sheet behind the Grown-ups button: the parental gate first, then the grown-ups area.
struct GrownupsSheet: View {
    let store: LearningStore

    var body: some View {
        NavigationStack {
            if store.gatePassed {
                GrownupsScreen(store: store)
            } else {
                GateScreen(store: store)
            }
        }
    }
}

/// The parental gate: a multiplication typed on a number pad. A right answer opens the
/// grown-ups area; a wrong one closes the gate, and the next opening asks something else.
/// When it opens it says, out loud, that this part is for grown-ups, for children who
/// can't read the screen yet.
struct GateScreen: View {
    let store: LearningStore

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn
    @ScaledMetric(relativeTo: .title) private var keyHeight = 64.0
    @Environment(\.dynamicTypeSize) private var typeSize

    private var question: GateQuestion { store.gate.question }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                Text(question.text)
                    .font(.largeTitle.bold().monospacedDigit())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(question.spoken)
                    .accessibilityIdentifier("gate.question")
                entry
                keypad
            }
            .padding(20)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("For grown-ups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { store.closeGate() }
                    .accessibilityIdentifier("gate.close")
            }
        }
        .task {
            if store.readsAloud && !voiceOverOn {
                store.speaker.say(AppFacts.gatePrompt)
            }
        }
        .testMarker("gate.state", value: "left=\(question.left)|right=\(question.right)|entry=\(store.gate.entry)|"
                    + "attempts=\(store.gate.attempts)|failures=\(store.gate.failures)|")
    }

    private var header: some View {
        // At accessibility text sizes the header stacks, so its words get the width.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 16))
        return layout {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Ask a grown-up")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("Answer this to change settings or open links.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { store.speaker.say(AppFacts.gatePrompt) } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color(.secondarySystemBackground)))
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Say who this is for")
            .accessibilityIdentifier("gate.speaker")
        }
    }

    private var entry: some View {
        Text(store.gate.entry.isEmpty ? "?" : store.gate.entry)
            .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
            .foregroundStyle(store.gate.entry.isEmpty ? .secondary : .primary)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemBackground)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Your answer")
            .accessibilityValue(store.gate.entry.isEmpty ? "Empty" : store.gate.entry)
            .accessibilityIdentifier("gate.entry")
    }

    private var keypad: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { digit in digitKey(digit) }
                }
            }
            GridRow {
                key(label: Label("Delete", systemImage: "delete.left").labelStyle(.iconOnly), id: "gate.delete") {
                    store.deleteGateDigit()
                }
                .accessibilityLabel("Delete")
                digitKey(0)
                key(label: Text("Check").font(.title3.bold()), id: "gate.check") {
                    store.checkGate()
                }
                .disabled(!store.gate.canCheck)
            }
        }
    }

    private func digitKey(_ digit: Int) -> some View {
        key(label: Text("\(digit)").font(.title.bold().monospacedDigit()), id: "gate.key.\(digit)") {
            store.typeGateDigit(digit)
        }
    }

    private func key(label: some View, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity, minHeight: keyHeight)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemBackground)))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier(id)
    }
}
