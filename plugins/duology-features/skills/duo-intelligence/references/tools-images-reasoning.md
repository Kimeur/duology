# Tools, images, guided choices and reasoning

Four Foundation Models features that fit a Duo pane. Each snippet typechecks against the iOS 27.1 simulator SDK in Swift 5 and Swift 6 mode. None of them was run against a working model: in our simulator every on-device request failed ([evidence](evidence.md#foundation-models-in-the-simulator)).

## Tool calling

A tool lets the model ask your app for facts it doesn't have ([Expanding generation with tool calling](https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling), [Tool](https://developer.apple.com/documentation/foundationmodels/tool)).

```swift
import Foundation
import FoundationModels

// Tool calling: the model asks your app for data it doesn't have.
@available(iOS 27.0, *)
struct FindNotesTool: Tool {
    let name = "findNotes"
    let description = "Finds the person's notes whose title contains a word, and returns their titles."

    @Generable
    struct Arguments {
        @Guide(description: "One word from the note title")
        var word: String
    }

    let titles: @Sendable () async -> [String]      // reads your store; keep the store off this type

    func call(arguments: Arguments) async throws -> String {
        let matches = await titles().filter { $0.localizedCaseInsensitiveContains(arguments.word) }
        return matches.isEmpty ? "No notes match." : matches.prefix(5).joined(separator: "\n")
    }
}

@available(iOS 27.0, *)
func answer(_ question: String, titles: @escaping @Sendable () async -> [String]) async throws -> String {
    let session = LanguageModelSession(
        model: SystemLanguageModel.default,
        tools: [FindNotesTool(titles: titles)],
        instructions: "Answer questions about the person's notes. Use findNotes to look them up."
    )
    return try await session.respond(to: question).content
}
```

- A tool must be `Sendable`. Pass a closure that reads your `@MainActor` store instead of holding the store.
- Tool output and its schema count against the context window. Return a few short lines, not whole notes.
- Tools that change data: confirm with the person first. Apple's HIG asks for confirmation before significant actions ([HIG: Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai)).
- On iPhone Duo, show what the tool found in the pane on the open phone, so people can check the model's answer against the source.

## Images

iOS 27 adds image input. Put an `Attachment` in the prompt builder ([Analyzing images with multimodal prompting](https://developer.apple.com/documentation/foundationmodels/analyzing-images-with-multimodal-prompting)).

```swift
import CoreGraphics
import FoundationModels

// Image input (iOS 27): an attachment in the prompt.
@available(iOS 27.0, *)
func caption(for photo: CGImage) async throws -> String? {
    let model = SystemLanguageModel.default
    guard model.isAvailable, model.capabilities.contains(.vision) else { return nil }
    let session = LanguageModelSession(model: model)
    let response = try await session.respond {
        "Write a one-sentence caption for this photo."
        Attachment(photo)
    }
    return response.content
}
```

- The framework scales and converts the image for you. Larger images cost more tokens and time (WWDC26 session [241](https://developer.apple.com/videos/play/wwdc2026/241/)).
- A frame from `AVFoundation` often has no rotation applied. Pass `orientation:` so the model sees it upright ([multimodal article](https://developer.apple.com/documentation/foundationmodels/analyzing-images-with-multimodal-prompting)). On iPhone Duo the camera that faces the person changes when the phone folds or flips; take the orientation from your capture code, not from the device orientation (`duo-camera`).
- Personal photos: say how the app uses them when you ask for Photos access ([safety guide](https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output)).

## Guided choices

```swift
import FoundationModels

// Guided generation with a closed set of answers.
@available(iOS 26.0, *)
@Generable
enum NoteKind {
    case shopping, travel, idea, other
}

@available(iOS 27.0, *)
func kind(of note: String) async throws -> NoteKind {
    let session = LanguageModelSession()
    return try await session.respond(
        to: "Which kind of note is this? \(note)",
        generating: NoteKind.self,
        options: GenerationOptions(samplingMode: .greedy)
    ).content
}
```

- An enum limits the answer to safe, known values, which Apple recommends when people can type anything ([safety guide](https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output)).
- `.greedy` makes the model pick the most likely case every time.
- A label like this fits the outer display's one-line summary as well as the open pane.

## Reasoning

`ContextOptions(reasoningLevel:)` (iOS 27) asks the model to think before it answers. Private Cloud Compute supports `.light`, `.moderate` and `.deep`; the on-device model reported no `.reasoning` capability (*measured*, [evidence](evidence.md#foundation-models-in-the-simulator)). Apple suggests starting at `.moderate` and going deeper only when evaluation shows a need. Reasoning text uses context tokens but doesn't appear in the response ([PCC guide](https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute)). `summarizeLongNote` in [models-and-availability.md](models-and-availability.md#errors-and-fallbacks) shows the call.

Deep reasoning can take a while. On the closed phone, show the one-line status ("Thinking through your document") and let people fold and unfold freely: the request belongs to the window's model, not to a view.
