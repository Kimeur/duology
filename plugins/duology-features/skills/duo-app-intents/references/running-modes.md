# Running modes: background, foreground and the closed phone

When an intent runs, the system decides whether your app comes forward. On iPhone Duo, "forward" means the outer display when the phone is closed and the inner display when it is open, so an intent that opens the app must work in both layouts. Most intents shouldn't open it at all.

## Modes

`supportedModes` (iOS 26) suggests how an intent runs. The system has the last word ([runtime guide](https://developer.apple.com/documentation/appintents/configuring-the-runtime-behavior-of-your-app-intents), [IntentModes](https://developer.apple.com/documentation/appintents/intentmodes)).

| `supportedModes` | Runs | Use for |
|---|---|---|
| `.background` | Without bringing the app forward | Reading, adding, toggling, summarizing: anything that can answer in words |
| `.foreground(.immediate)` | The app comes forward as soon as the parameters resolve | Showing something in the app |
| `.foreground(.dynamic)` with `.background` | In the background; `perform()` may call `continueInForeground(_:alwaysConfirm:)` | Usually quiet, sometimes needs the screen |
| `.foreground(.deferred)` | In the background; forward when you call `continueInForeground`, or at the end of `perform()` | Work that ends on a screen |

- `OpenIntent`, `ShowInAppSearchResultsIntent`, `PlayVideoIntent`, `StartWorkoutIntent` and `LiveActivityIntent` set the foreground for you. Code in an App Intents extension or a widget extension always runs in the background.
- Read the actual mode from `systemContext.currentMode`; call `continueInForeground` only when `canContinueInForeground` is true. An extension can't continue in the foreground.
- `allowedExecutionTargets` (iOS 27) restricts an intent to the app, the App Intents extension or the widget extension, when the same code is in several ([doc](https://developer.apple.com/documentation/appintents/appintent/allowedexecutiontargets)).
- `openAppWhenRun` and `ForegroundContinuableIntent` are deprecated in iOS 26 in favour of `supportedModes`.

*Measured* on the iPhone Duo simulator, closed and open: an intent with `.background` reported `IntentMode.background` in `perform()`, and the scene stayed in the background. An `OpenIntent` reported `IntentMode.foreground`.

## A result for the closed phone

The closed phone has a small display, and the phone may be in a pocket. Return words first, and a small view if it helps.

```swift
import AppIntents
import SwiftUI

// requires: NoteLibrary, NoteEntity (SKILL.md)

/// A small result view. The system shows it on whichever display is in use,
/// so size it to its content and keep it short.
struct NoteSnippet: View {
    let title: String
    let excerpt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(excerpt).font(.subheadline).lineLimit(3)
        }
        .padding()
    }
}

struct ShowNoteSnippetIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Note Preview"
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Note") var note: NoteEntity

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let excerpt = await MainActor.run { String(NoteLibrary.shared.note(note.id)?.body.prefix(140) ?? "") }
        return .result(
            dialog: IntentDialog(full: "\(note.title): \(excerpt)", supporting: "Here's \(note.title)."),
            view: NoteSnippet(title: note.title, excerpt: excerpt)
        )
    }
}
```

- The `full` dialog carries everything; Siri may only speak it. The `supporting` text goes with the view ([IntentDialog](https://developer.apple.com/documentation/appintents/intentdialog), [WWDC26 session 343](https://developer.apple.com/videos/play/wwdc2026/343/)).
- `systemContext.isVoiceOnly` (iOS 27) is true when nothing will be shown. Check it when you generate free-form text, such as a model summary, and make it speakable ([doc](https://developer.apple.com/documentation/appintents/intentsystemcontext/isvoiceonly)).
- Keep the view to a few lines with a flexible width. *Unverified:* how wide a snippet is on the outer display and the inner display. Don't assume one width.

## Coming forward only when needed

```swift
import AppIntents

// requires: NoteLibrary, NoteEntity (SKILL.md)

/// Starts in the background; asks to come forward only when the text is long.
struct AppendToNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Add to Note"
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Parameter(title: "Note") var note: NoteEntity
    @Parameter(title: "Text") var text: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        if text.count > 500, systemContext.currentMode.canContinueInForeground {
            // The app opens on whichever display is in use; its compact layout must handle it.
            try await continueInForeground(IntentDialog("That's a long addition. Open the note to check it?"))
        }
        await MainActor.run {
            guard let index = NoteLibrary.shared.notes.firstIndex(where: { $0.id == note.id }) else { return }
            NoteLibrary.shared.notes[index].body += "\n" + text
        }
        return .result(dialog: "Added to \(note.title).")
    }
}
```

- `continueInForeground` can ask the person first (`alwaysConfirm`, true by default). When the app can't come forward, it throws `notAllowed`, so check `canContinueInForeground` first ([doc](https://developer.apple.com/documentation/appintents/appintent/continueinforeground(_:alwaysconfirm:))).
- After it returns, the app is in front on the outer or the inner display. Whatever the intent shows next must work in the compact layout: the phone may be closed.
- *Unverified* on Duo: this hand-off. We measured only `.background` and `OpenIntent`.

## Long work

An intent gets about 30 seconds ([LongRunningIntent](https://developer.apple.com/documentation/appintents/longrunningintent)). For longer work, adopt `LongRunningIntent` (iOS 27), run the work in `performBackgroundTask(options:operation:)` and update `progress`; the system shows progress as a Live Activity and adds a stop button ([WWDC26 session 345](https://developer.apple.com/videos/play/wwdc2026/345/)). Add `CancellableIntent` (iOS 26.4) to clean up when it stops. None of this depends on the pose, which is the point: the phone can fold while it runs.
