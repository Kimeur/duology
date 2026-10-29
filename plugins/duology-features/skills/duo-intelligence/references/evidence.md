# Evidence

What we ran for this skill, on what, and what came out. Everything here is *measured* unless a line says otherwise. Two probes ran: the first with a `NavigationSplitView` and an `AnyLayout` switch, the second with this skill's `NoteScreen`.

## Setup

- Xcode 27.1 (27A9275), iOS 27.1 simulator SDK (24A94232), the shared "iPhone Duo" simulator (iOS 27.1, 24A94425).
- Host: a MacBook Pro with an Apple M2 chip, macOS 27.0.1. We did not check or change the Mac's Apple Intelligence settings.
- 20 October 2026. Poses set with `duo-pose` from `duo-pose-matrix` (Device Hub's Closed, Open, Partially Open and Rotate Right buttons). Other apps shared the simulator during the runs; we kept only results from moments our app was in front.
- A probe app, deployment target iOS 27.1, Swift 6: a `NavigationSplitView` of three notes, a detail view whose layout switches with `AnyLayout` (side by side when regular, stacked when compact), and a window-owned `@Observable` model that runs the request in a `Task`. It logged with `os.Logger` and we read the log with `xcrun simctl spawn <udid> log show`.

## Foundation Models in the simulator

| What | Result |
|---|---|
| `SystemLanguageModel.default.availability` | `.available`, `isAvailable` true |
| `SystemLanguageModel.default.contextSize` | 0 |
| `supportsLocale()` (English) | true |
| `variant.displayName` | "AFM 3 Core" |
| `capabilities` on device | `.vision`, `.toolCalling`, `.guidedGeneration`: yes. `.reasoning`: no |
| `PrivateCloudComputeLanguageModel().availability`, no entitlement | `.available`, `isAvailable` true |
| `capabilities` of Private Cloud Compute | all four, `.reasoning` included |
| `streamResponse(to:)` on device | Failed 2 to 12 s after the request, in two runs: an `NSError`, domain `FoundationModels.LanguageModelError`, code -1, with an underlying `com.apple.SensitiveContentAnalysisML` error 15 |
| The same with `SystemLanguageModel(guardrails: .permissiveContentTransformations)` | Failed the same way: domain `FoundationModels.LanguageModelError`, code -1 |
| `respond(to:)` on device, inside an App Intent | Same `NSError` as the stream |
| `respond(to:)` on Private Cloud Compute, no entitlement | No answer and no error after 9 minutes; we stopped the app |

What this means for the skill:

- Availability said yes and every request still failed. So the skill asks for a fallback on every request, not only when availability says no.
- The failure was an `NSError`, not a `LanguageModelError` value, so `catch let error as LanguageModelError` didn't match it. The skill ends every request with a plain `catch`.
- A request can hang. The skill keeps Stop on screen.
- The simulator itself refuses the requests (*measured* on 29 October 2026, with `recipe-notes-ai`'s app): the error's underlying cause, in the app's log, reads "InferenceError::operationNotAllowed::Simulator is not supported", from the guardrail's text sanitizer (`com.apple.SensitiveContentAnalysisML` error 15). Judge output, speed and refusals on a device with Apple Intelligence on.

## A stream through fold and unfold

The real model couldn't answer here, so we used a stand-in: the same window-owned model and `Task`, appending one word every 250 ms for 80 words. It tests the part iPhone Duo changes, the view tree around the stream.

| Run | What happened |
|---|---|
| Launched closed, Open pressed after about 6 s | The width class went from compact to regular just after chunk 24. Chunks kept coming: 28 came 1.7 s after 24 instead of the usual 1.0 s, then the normal pace. The detail view's `onAppear` ran once, at launch. The selection stayed on the same note. |
| Launched open, Closed pressed after about 6 s | The width class went from regular to compact just after chunk 24. The next gaps were 1.4 s, 1.9 s and 2.4 s per four chunks, then 1.0 s again. No new `onAppear`, same selection, all 80 chunks arrived. |

- The hinge reported several `partiallyOpen` updates during each change; the size class changed once.
- *Unverified:* the same with a real model on a device, and at 120 Hz.

## The pane in each pose

A second probe, on 20 October 2026, ran the skill's own code: `AssistantModel`, `NoteScreen` (the split `ArrangementView` with the bar in a bottom inset), `AssistantPane` and `AssistantSummaryBar`. Only the stream was a stand-in: the same window-owned task wrote a partial `NoteDigest` every 0.4 s for 200 steps, headline first. Poses were set with `duo-pose`, and we took a screenshot of the active display in each one. Nothing else used the simulator during this run.

| Pose | Root view inside the safe area | What showed |
|---|---|---|
| Closed | 382 × 644 pt, compact width | The note, and at the bottom the bar with the streaming headline and Details. No pane. |
| Open, flat | 867 × 635 pt, regular width | The note leading and the pane trailing, 433.7 pt each. The pane showed the headline, the points so far, "Summarizing your note" and Stop. |
| Book | 867 × 635 pt | Still side by side. The note now ended at 455.7 pt, 20 pt before the middle of the 951 pt display, and the pane's text began right of the fold. The arrangement moved the seam onto the fold by itself. |
| Tabletop | 669 × 835 pt, regular width | The note alone across the window, and the bar at the bottom, in the bottom region. No pane. |
| Closed again | 382 × 644 pt | The note and the bar with the full headline. |

- The stream never restarted: all 200 steps arrived, the window root and the note view each appeared once, at launch. Ten steps took 4.1 to 4.2 s, except 5.3 s across the change to open and 4.7 s across the change to book.
- Flat and open, the seam sat at the middle of the safe area, not of the display: the vertical bar takes the trailing edge. That is fine while the fold is flat. Folded, the arrangement moved it.
- *Not checked:* the Details sheet and its dismissal when the pane fits beside (no taps in this run), Split View, and a real model.

## The first probe's core

The parts that matter, cut down. Neither probe is in the repo.

```swift
import SwiftUI
import Observation

@MainActor @Observable
final class ProbeModel {
    var text = ""
    var chunks = 0
    private var task: Task<Void, Never>?

    func standInStream() {
        task?.cancel()
        task = Task {
            for _ in 0..<80 {
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
                chunks += 1
                text += "word "
            }
        }
    }
}

struct ProbeDetail: View {
    let model: ProbeModel
    @Environment(\.horizontalSizeClass) private var width

    var body: some View {
        let layout = width == .regular
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 24))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        layout {
            Text("Note")
            Text(model.text).lineLimit(width == .regular ? nil : 2)
        }
        .onAppear { print("detail appeared") }          // logged once per identity
    }
}
```

## Not covered

- Output quality, speed and token use on a real iPhone Duo.
- Private Cloud Compute with the entitlement, its quota UI and the scheme's simulated quota options.
- Split View: which size class a half of the inner display reports, and where the pane goes.
- The UIKit version (`NoteScreenController`); it typechecks but didn't run.
