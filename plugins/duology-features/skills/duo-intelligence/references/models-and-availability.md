# Models, availability and errors

The Foundation Models types this skill uses, checked in the iOS 27.1 simulator SDK (`FoundationModels.swiftinterface`, Xcode 27.1, 20 October 2026), then the code for availability, quotas and fallbacks.

## API table

Declarations are shortened: no module prefixes, no `final public`, no isolation keywords. "iOS 27.0" means the SDK's `@available` says so.

| API | Declaration (short) | Since | Apple doc |
|---|---|---|---|
| `SystemLanguageModel` | `final class SystemLanguageModel : Sendable`, `Observable`; `static var default`, `init(useCase:guardrails:)` | iOS 26.0 | [doc](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel) |
| `SystemLanguageModel.availability` | `var availability: SystemLanguageModel.Availability { get }`; `@frozen enum Availability` with `.available`, `.unavailable(UnavailableReason)`; reasons `.deviceNotEligible`, `.appleIntelligenceNotEnabled`, `.modelNotReady` | iOS 26.0 | [doc](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.property) |
| `SystemLanguageModel.contextSize`, `tokenCount(for:)` | `var contextSize: Int { get }` (`@backDeployed(before: iOS 26.4)`; the back-deployed copy returns 4096 below iOS 27); `func tokenCount(for prompt: some PromptRepresentable) async throws -> Int` and overloads | iOS 26.0; `tokenCount` iOS 26.4 | [doc](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel) |
| `SystemLanguageModel.variant` | `var variant: SystemLanguageModel.Variant { get }`; `Variant` has `displayName`, `static var core3`, `coreAdvanced3` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel) |
| `SystemLanguageModel.Error` | `enum Error : LocalizedError` with `.assetsUnavailable(_)`, the replacement for `GenerationError.assetsUnavailable` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel) |
| `SystemLanguageModel.Guardrails` | `static let default`, `static let permissiveContentTransformations` | iOS 26.0 | [doc](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel) |
| `PrivateCloudComputeLanguageModel` | `final class PrivateCloudComputeLanguageModel : Sendable`, `Observable`, `LanguageModel`; `init()`; `availability` with reasons `.deviceNotEligible`, `.systemNotReady`; `isAvailable` | iOS 27.0 (also watchOS 27.0) | [doc](https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel) |
| `PrivateCloudComputeLanguageModel.quotaUsage` | `var quotaUsage: QuotaUsage { get }`; `QuotaUsage` has `status` (`.belowLimit(BelowLimit)` with `isApproachingLimit`, `.limitReached(_)`), `isLimitReached`, `resetDate: Date?`, `limitIncreaseSuggestion: LimitIncreaseSuggestion?` with `func show()` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel/quotausage-swift.property) |
| `PrivateCloudComputeLanguageModel.Error` | `enum Error : Error, LocalizedError` with `.networkFailure(_)`, `.quotaLimitReached(_)` (has `resetDate`), `.serviceUnavailable(_)` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel) |
| `LanguageModel` | `protocol LanguageModel : Sendable` with `var capabilities: LanguageModelCapabilities { get }`; capabilities `.vision`, `.guidedGeneration`, `.reasoning`, `.toolCalling`, checked with `contains(_:)` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/languagemodel) |
| `LanguageModelSession.init(model:tools:instructions:)` | `convenience init(model: some LanguageModel, tools: [any Tool] = [], instructions: Instructions? = nil)`, plus `String?` and builder overloads | iOS 27.0; the `SystemLanguageModel` form is iOS 26.0 | [doc](https://developer.apple.com/documentation/foundationmodels/languagemodelsession) |
| `LanguageModelSession.streamResponse(to:generating:…)` | `func streamResponse<Content>(to prompt: String, generating type: Content.Type = Content.self, …) -> sending ResponseStream<Content> where Content : Generable` | iOS 26.0; `contextOptions:` overloads iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/languagemodelsession) |
| `LanguageModelSession.ResponseStream` | `AsyncSequence` of `Snapshot` with `content: Content.PartiallyGenerated`, `rawContent`; `func collect() async throws -> sending Response<Content>` | iOS 26.0 | [doc](https://developer.apple.com/documentation/foundationmodels/languagemodelsession) |
| `LanguageModelSession.isResponding`, `transcript`, `prewarm(promptPrefix:)`, `usage` | `var isResponding: Bool { get }`; `var transcript: Transcript`; `func prewarm(promptPrefix: Prompt? = nil)`; `var usage: Usage { get }` | iOS 26.0; `usage` iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/languagemodelsession) |
| `LanguageModelSession.Error` | `enum Error : LocalizedError` with `.concurrentRequests`, `.transcriptMutationWhileResponding` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/languagemodelsession) |
| `LanguageModelError` | `enum LanguageModelError : LocalizedError` with `.contextSizeExceeded`, `.rateLimited`, `.guardrailViolation`, `.refusal`, `.unsupportedCapability`, `.unsupportedTranscriptContent`, `.unsupportedGenerationGuide`, `.unsupportedLanguageOrLocale`, `.timeout` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/languagemodelerror) |
| `@Generable`, `@Guide` | `macro Generable(description: String? = nil)`; `macro Guide<T>(description: String? = nil, _ guides: GenerationGuide<T>...)`; `GenerationGuide` has `.count(_:)`, `.range(_:)`, `.anyOf(_:)` and more | iOS 26.0 | [doc](https://developer.apple.com/documentation/foundationmodels/generable) |
| `GenerationOptions` | `init(samplingMode:temperature:maximumResponseTokens:)`; `SamplingMode.greedy`; `toolCallingMode` iOS 27.0 | iOS 26.0 | [doc](https://developer.apple.com/documentation/foundationmodels/generationoptions) |
| `ContextOptions` | `init(includeSchemaInPrompt: Bool? = nil, reasoningLevel: ReasoningLevel? = nil)`; `ReasoningLevel` has `.light`, `.moderate`, `.deep`, `.custom(String)` | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/contextoptions) |
| `Attachment` | `struct Attachment<Content>` with `init(_ cgImage: CGImage, orientation:)`, `init(_ ciImage:orientation:)`, `init(_ pixelBuffer:orientation:)`, `init(imageURL:orientation:)`, `func label(_:)`; `init(_ uiImage: UIImage, orientation:)` comes with UIKit | iOS 27.0 | [doc](https://developer.apple.com/documentation/foundationmodels/attachment) |
| `Tool` | `protocol Tool<Arguments, Output> : Sendable` with `name`, `description`, `parameters`, `func call(arguments:) async throws -> Output` | iOS 26.0 | [doc](https://developer.apple.com/documentation/foundationmodels/tool) |

Also in the 27.1 SDK, not used here: dynamic profiles (`LanguageModelSession.DynamicProfile`, `Profile`), custom model executors (`LanguageModelExecutor`), and `SpotlightSearchTool`, which appears when you import both CoreSpotlight and FoundationModels.

### Names that sound right but aren't in the iOS 27.1 SDK

- **`BarcodeReaderTool`, `OCRTool`**: WWDC26 session [241](https://developer.apple.com/videos/play/wwdc2026/241/) and Apple's [multimodal article](https://developer.apple.com/documentation/foundationmodels/analyzing-images-with-multimodal-prompting) name them. We found neither in any interface of the iOS 27.1 simulator SDK. Don't use them in an iOS 27.1 app until they appear.
- **`SystemLanguageModel.Adapter`** (custom adapters): deprecated in iOS 26.4 and obsoleted in iOS 27.0.
- **`LanguageModelSession.GenerationError`**: still there, deprecated in iOS 27.0. Each case's message names its `LanguageModelError` replacement.

## Availability

Check the on-device model before you show the feature, and the server model before you route to it.

| `SystemLanguageModel` reason | Show |
|---|---|
| `.deviceNotEligible` | The feature's non-AI version. Don't promise it later. |
| `.appleIntelligenceNotEnabled` | The non-AI version, and a line that Apple Intelligence in Settings turns it on. |
| `.modelNotReady` | The non-AI version for now. The model may still be downloading ([Generating content](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)). |

`PrivateCloudComputeLanguageModel` has its own reasons, `.deviceNotEligible` and `.systemNotReady`. Its `contextSize`, `supportedLanguages` and `supportsLocale(_:)` are `async throws` in the SDK, unlike the on-device model's.

*Measured* on the iPhone Duo simulator: both models reported `.available`, the on-device model reported a `contextSize` of 0, and on-device requests failed (see [evidence](evidence.md#foundation-models-in-the-simulator)). Availability says the model may run. Only a successful response says it did.

## Private Cloud Compute

- Ask Apple for the managed entitlement `com.apple.developer.private-cloud-compute` ([entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.private-cloud-compute), [Accessing Private Cloud Compute](https://developer.apple.com/private-cloud-compute/)). WWDC26 session [319](https://developer.apple.com/videos/play/wwdc2026/319/) says it is open to apps with fewer than 2 million downloads, with no token cost to you.
- Each person gets a daily limit, counted on their iCloud account; iCloud+ raises it. Apple asks for a persistent note near the button, not an alert ([PCC guide](https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute)).
- Test the limit without hitting it: the scheme's Run options have "Simulated Apple Foundation Models Availability" with "Approaching Quota Usage Limit" and "Quota Usage Limit Reached".
- *Measured:* in the simulator, without the entitlement, `respond` on Private Cloud Compute neither answered nor threw for 9 minutes. Give every request a Stop button, and cancel the task when the person leaves the screen on purpose (not on a fold).

### Quota note

```swift
import SwiftUI
import FoundationModels

/// A quiet, persistent line under the button that uses Private Cloud Compute.
/// Apple asks for this instead of an alert you can dismiss.
@available(iOS 27.0, *)
struct CloudQuotaNote: View {
    let model: PrivateCloudComputeLanguageModel

    var body: some View {
        let usage = model.quotaUsage
        VStack(alignment: .leading, spacing: 4) {
            if usage.isLimitReached {
                Text("You've reached today's limit for long summaries.")
            } else if case .belowLimit(let info) = usage.status, info.isApproachingLimit {
                Text("You're close to today's limit for long summaries.")
            }
            if let suggestion = usage.limitIncreaseSuggestion {
                Button("Get more") { suggestion.show() }
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
```

On iPhone Duo, put this note in the pane on the open phone and under the one-line summary on the closed phone. It must not disappear when the phone folds.

## Errors and fallbacks

```swift
import FoundationModels

/// Asks Private Cloud Compute first when the person allowed it, then the on-device model.
/// Returns nil when neither can answer, so the caller shows its non-AI fallback.
@available(iOS 27.0, *)
func summarizeLongNote(_ text: String, cloudAllowed: Bool) async -> String? {
    let instructions = "Summarize the document in five short points."
    if cloudAllowed {
        let cloud = PrivateCloudComputeLanguageModel()
        if cloud.isAvailable && !cloud.quotaUsage.isLimitReached {
            let session = LanguageModelSession(model: cloud, instructions: instructions)
            do {
                return try await session.respond(
                    to: text,
                    contextOptions: ContextOptions(reasoningLevel: .moderate)   // Apple's starting point; evaluate before changing
                ).content
            } catch PrivateCloudComputeLanguageModel.Error.networkFailure {
                // Offline: fall through to the on-device model.
            } catch PrivateCloudComputeLanguageModel.Error.quotaLimitReached {
                return nil      // the quota note in the pane explains why
            } catch {
                // Other failures: try on device below.
            }
        }
    }
    guard SystemLanguageModel.default.isAvailable else { return nil }
    let session = LanguageModelSession(instructions: instructions)
    do {
        return try await session.respond(to: String(text.prefix(6_000))).content
    } catch let error as LanguageModelError {
        switch error {
        case .guardrailViolation, .refusal:
            return "This note can't be summarized."
        case .contextSizeExceeded:
            return nil      // split the note and summarize the parts instead
        default:
            return nil
        }
    } catch {
        return nil          // measured: the simulator reported its failure as a plain NSError
    }
}
```

- The 6,000-character cut keeps an English text well under the on-device 4,096-token window (Apple counts three to four characters per token in English, one per character in Chinese, Japanese and Korean). For other languages, count with `tokenCount(for:)` (iOS 26.4) instead ([Managing the context window](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window)).
- With guided generation there is no refusal text; the session throws `.refusal`. Its `explanation` asks the model why, which takes another request ([safety guide](https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output)).
- `.permissiveContentTransformations` turns off the on-device guardrail checks for string output only. Use it only when your audience and task call for it, such as tagging chat messages that contain swearing.

### Unavailable note

```swift
import SwiftUI

// requires: AssistantModels (SKILL.md)

/// Shown instead of the Summarize button when the model can't run.
@available(iOS 27.0, *)
struct AssistantUnavailableNote: View {
    var body: some View {
        if let reason = AssistantModels.unavailableReason {
            Label(reason, systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
```
