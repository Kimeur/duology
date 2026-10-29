import SwiftUI

/// The full summary: what made it (AI or not), the headline, the key points and the to-dos,
/// with Summarize, Stop, Summarize Again and Clear at the bottom. Beside the note when the
/// phone is open, below the fold in tabletop, and in a sheet on the closed phone.
///
/// Everything it shows comes from the store, so a fold that swaps the bar for this pane (or
/// back) shows the same summary, even one still streaming in.
struct SummaryPane: View {
    let noteID: Note.ID
    let store: NotesStore

    private var note: Note? { store.note(noteID) }
    private var service: SummaryService { store.summaries }
    private var isWorking: Bool { service.isWorking(on: noteID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if isWorking {
                    working
                } else if let digest = note?.digest {
                    summary(digest)
                } else {
                    empty
                }
                Text(AppFacts.privacyLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("summary.privacy")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            controls
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(.bar)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
        .frameMarker("summary.pane")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Summary")
    }

    // MARK: Parts

    /// Says which summaries come from AI, always (HIG: Generative AI).
    @ViewBuilder
    private var header: some View {
        let origin = isWorking ? Digest.Origin.onDeviceAI : note?.digest?.origin
        if origin == .simple {
            Label(AppFacts.simpleLabel, systemImage: "text.alignleft")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("summary.label")
        } else {
            Label(AppFacts.aiLabel, systemImage: "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(.tint)
                .accessibilityIdentifier("summary.label")
        }
    }

    @ViewBuilder
    private var working: some View {
        let draft = service.draft ?? DigestDraft()
        HStack(spacing: 8) {
            ProgressView()
            Text("Summarizing…")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        if let headline = draft.headline, !headline.isEmpty {
            Text(headline)
                .font(.title3.bold())
                .accessibilityIdentifier("summary.draftHeadline")
        }
        list(draft.points, symbol: "circle.fill", id: "point")
        if !draft.todos.isEmpty {
            todos(draft.todos)
        }
    }

    @ViewBuilder
    private func summary(_ digest: Digest) -> some View {
        Text(digest.headline)
            .font(.title3.bold())
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("summary.headline")
        list(digest.points, symbol: "circle.fill", id: "point")
        if !digest.todos.isEmpty {
            todos(digest.todos)
        }
        if note?.summaryIsCurrent == false {
            notice("The note changed after this summary.", symbol: "clock.arrow.circlepath", id: "summary.outOfDate")
        }
        if !digest.coversWholeNote {
            notice(AppFacts.longNoteLine, symbol: "text.append", id: "summary.longNote")
        }
        if let reason = digest.fallbackReason {
            notice(reason, symbol: "info.circle", id: "summary.fallback")
        }
    }

    @ViewBuilder
    private var empty: some View {
        if note?.canBeSummarized == true {
            Text("Get the headline, the key points and the to-dos of this note.")
                .foregroundStyle(.secondary)
            if let reason = service.unavailableReason {
                notice("\(reason) You'll get a simple summary instead, picked from the note's own sentences.",
                       symbol: "info.circle", id: "summary.unavailable")
            }
        } else {
            Text("Write a few more lines to get a summary.")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("summary.tooShort")
        }
    }

    private func list(_ items: [String], symbol: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Label {
                    Text(item)
                } icon: {
                    Image(systemName: symbol)
                        .font(.system(size: 6))
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("summary.\(id).\(index)")
            }
        }
    }

    private func todos(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("To-dos")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Label(item, systemImage: "circle")
                    .accessibilityIdentifier("summary.todo.\(index)")
            }
        }
    }

    private func notice(_ text: String, symbol: String, id: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier(id)
    }

    /// The pane's buttons: people can always stop, redo or remove a summary.
    @ViewBuilder
    private var controls: some View {
        if isWorking {
            Button("Stop", systemImage: "stop.fill") { store.stopSummary() }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("summary.stop")
        } else if let note, let digest = note.digest {
            // Side by side when they fit; one above the other at large text sizes.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { againAndClear(note, digest) }
                VStack(spacing: 12) { againAndClear(note, digest) }
            }
            .controlSize(.large)
        } else {
            Button("Summarize", systemImage: "sparkles") { store.summarize(noteID) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(note?.canBeSummarized != true)
                .accessibilityIdentifier("summary.summarize")
        }
    }

    /// Summarize Again stands out when the summary is out of date or isn't from AI.
    @ViewBuilder
    private func againAndClear(_ note: Note, _ digest: Digest) -> some View {
        Button("Summarize Again", systemImage: "arrow.clockwise") { store.summarize(noteID) }
            .buttonStyle(.borderedProminent)
            .tint(note.summaryIsCurrent && digest.fallbackReason == nil ? Color.gray : Color.accentColor)
            .disabled(!note.canBeSummarized)
            .accessibilityIdentifier("summary.again")
        Button("Clear", systemImage: "xmark") { store.clearSummary(of: noteID) }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("summary.clear")
    }
}

/// The summary in one line, for the closed phone: the headline (or what's happening) and one
/// button. Details opens the full pane in a sheet. Same feature, less of it.
struct SummaryBar: View {
    let noteID: Note.ID
    let store: NotesStore

    private var note: Note? { store.note(noteID) }
    private var isWorking: Bool { store.summaries.isWorking(on: noteID) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: note?.digest?.origin == .simple && !isWorking ? "text.alignleft" : "sparkles")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(line)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .accessibilityIdentifier("summary.barLine")
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            button
        }
        .padding(.horizontal, 16)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .frameMarker("summary.bar")
    }

    private var line: String {
        if isWorking {
            let headline = store.summaries.draft?.headline ?? ""
            return headline.isEmpty ? "Summarizing…" : headline
        }
        if let digest = note?.digest { return digest.headline }
        return note?.canBeSummarized == true ? "No summary yet" : "Write more to get a summary"
    }

    private var detail: String? {
        if isWorking { return AppFacts.aiLabel }
        guard let note, let digest = note.digest else { return nil }
        if !note.summaryIsCurrent { return "The note changed after this summary" }
        return digest.origin == .simple ? AppFacts.simpleLabel : AppFacts.aiLabel
    }

    @ViewBuilder
    private var button: some View {
        if isWorking {
            Button("Stop", systemImage: "stop.fill") { store.stopSummary() }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("summary.stop")
        } else if note?.digest != nil {
            Button("Details") { store.showsSummarySheet = true }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("summary.details")
        } else {
            Button("Summarize", systemImage: "sparkles") { store.summarize(noteID) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(note?.canBeSummarized != true)
                .accessibilityIdentifier("summary.summarize")
        }
    }
}

/// The full summary of the note on screen, on the closed phone.
struct SummarySheet: View {
    let store: NotesStore

    var body: some View {
        NavigationStack {
            Group {
                if let id = store.path.last {
                    SummaryPane(noteID: id, store: store)
                } else {
                    ContentUnavailableView("No Note Open", systemImage: "note.text")
                }
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { store.showsSummarySheet = false }
                        .accessibilityIdentifier("summary.done")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
