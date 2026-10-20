# The assistant pane

The views behind `NoteScreen` in SKILL.md, the window root that owns the assistant, a UIKit version, and notes for book, tabletop, Split View and several windows.

The code uses the `AssistantModel`, `NoteDigest` and `AssistantModels` types from SKILL.md, and a `Note` type of your own (`id`, `title`, `body`).

## The pane, the summary bar and the status line

```swift
import SwiftUI
import FoundationModels

/// The full pane: beside the note when it fits, in a sheet otherwise.
@available(iOS 27.0, *)
struct AssistantPane: View {
    let model: AssistantModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label("AI summary", systemImage: "sparkles")       // say where AI is used
                    .font(.headline)
                if let headline = model.digest?.headline {
                    Text(headline).font(.title3)
                }
                ForEach(Array((model.digest?.points ?? []).enumerated()), id: \.offset) { _, point in
                    Label(point, systemImage: "circle.fill")
                        .labelStyle(BulletLabelStyle())
                }
                AssistantStatus(model: model)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Closed, tabletop or a narrow window: one line, and a way to the full pane.
@available(iOS 27.0, *)
struct AssistantSummaryBar: View {
    let model: AssistantModel
    let showDetails: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").accessibilityHidden(true)
            Text(model.digest?.headline ?? placeholder)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Details", action: showDetails)
        }
        .padding()
        .background(.bar)
        .accessibilityElement(children: .combine)
    }

    private var placeholder: String {
        switch model.phase {
        case .working: "Summarizing your note…"            // say what the model is doing
        case .failed: "No summary. Open Details to try again."
        case .idle, .done: "No summary yet"
        }
    }
}

/// Progress, errors, Stop and Retry, shared by the pane and the sheet.
@available(iOS 27.0, *)
struct AssistantStatus: View {
    let model: AssistantModel

    var body: some View {
        switch model.phase {
        case .working:
            HStack {
                ProgressView()
                Text("Summarizing your note")
                Spacer()
                Button("Stop") { model.stop() }
            }
        case .failed(let message):
            HStack {
                Text(message).foregroundStyle(.secondary)
                Spacer()
                Button("Retry") { model.retry() }
            }
        case .done:
            Button("Summarize again") { model.retry() }
        case .idle:
            EmptyView()
        }
    }
}

struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.font(.system(size: 6)).foregroundStyle(.secondary)
            configuration.title
        }
    }
}
```

- The headline arrives first because `NoteDigest` declares it first. The bar shows it while the points are still coming.
- The bar holds one line and one button, so it fits the closed phone held sideways, where the window is 678 × 466 pt (*measured*, [device facts](https://github.com/Kimeur/duology/blob/main/reference/device-facts.md#displays)).
- Status messages say what the model is doing, not "Processing", as the HIG asks ([HIG: Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai)).
- Put Stop and Retry in the pane's status line, not in a toolbar the system may move. In book pose the pane is the arrangement's trailing view, so they stay out of the fold.

## The window root owns the assistant

```swift
import SwiftUI

/// The window root owns the assistant, so a fold never resets it.
@available(iOS 27.1, *)
struct NoteWindow: View {
    let note: Note
    @State private var assistant = AssistantModel()

    var body: some View {
        NavigationStack {
            NoteScreen(note: note, assistant: assistant)    // the ArrangementView goes inside the stack
                .navigationTitle(note.title)
                .toolbar {
                    Button("Summarize", systemImage: "sparkles") {
                        if let model = AssistantModels.choose(needsLargeContext: false, cloudAllowed: false) {
                            assistant.summarize(note.body, with: model)
                        }
                    }
                    .disabled(AssistantModels.unavailableReason != nil || assistant.phase == .working)
                }
        }
    }
}
```

- `NoteWindow` never changes identity, so neither does the assistant. The arrangement below it may hide or show the pane as often as the phone folds.
- In a `NavigationSplitView`, keep the assistant next to the selection in your window model, not in the detail view. The detail column leaves the view tree when the phone closes (`duo-continuity`). Put the `ArrangementView` in the detail column's own `NavigationStack`, never around the split view.
- One assistant per window. Two windows on the inner display are two scenes; each gets its own `AssistantModel`, and both read the same app-wide store (`duo-scenes`).

## Book, tabletop and Split View

- **Book** (partly folded, held wide): the split arrangement keeps one view on each side of the fold, note leading and pane trailing. Apple's arrangements adapt to the fold for you ([overview](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)). Our probe: [evidence](evidence.md#the-pane-in-each-pose).
- **Tabletop** (partly folded, held tall): the window is taller than wide, so a horizontal-only split shows the note alone and the bar takes the bottom of the window. Apple puts what people tap in the bottom region in this pose ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=274)). Details opens the sheet, and the system keeps sheets clear of the fold ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)).
- **Split View**: the window gets half the inner display. `paneIsBeside` follows its width class and shape. *Unverified:* which size class a Split View half reports on iPhone Duo.
- **Why not a full split in tabletop?** Without `.axes(.horizontal)`, the split also stacks. Closed and held tall, it would then cut the outer display in two (`duo-layout` measured stacked halves at compact width). One rule for every pose is simpler: the pane beside, or the bar.

## UIKit

The model works unchanged. UIKit tracks the `@Observable` properties you read in `updateProperties()` and calls it again when they change (iOS 26, [observation tracking in UIKit](https://developer.apple.com/documentation/uikit/updating-views-automatically-with-observation-tracking-in-uikit)).

```swift
import UIKit
import FoundationModels

/// UIKit version of NoteScreen: a split arrangement inside the navigation controller,
/// plus a one-line bar when the pane can't sit beside the note.
@available(iOS 27.1, *)
final class NoteScreenController: UIViewController {
    private let assistant: AssistantModel              // owned by the scene, handed down
    private let note: UIViewController
    private let arrangement = UIArrangementViewController()
    private let bar = UIButton(configuration: .plain())

    init(note: UIViewController, assistant: AssistantModel) {
        self.note = note
        self.assistant = assistant
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        arrangement.setViewController(note, for: .primary)
        arrangement.setViewController(AssistantViewController(assistant: assistant), for: .secondary)
        arrangement.updateArrangement(.split.axes(.horizontal))     // beside, never below
        addChild(arrangement)
        bar.addAction(UIAction { [weak self] _ in self?.showPaneSheet() }, for: .primaryActionTriggered)
        let stack = UIStackView(arrangedSubviews: [arrangement.view, bar])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        arrangement.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The same rule as the SwiftUI version. state(for:).isHidden read false while hidden (duo-layout).
        let beside = traitCollection.horizontalSizeClass == .regular && view.bounds.width > view.bounds.height
        if bar.isHidden != beside { bar.isHidden = beside }
        if beside, presentedViewController is AssistantViewController { dismiss(animated: true) }
    }

    override func updateProperties() {
        super.updateProperties()
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "sparkles")
        config.imagePadding = 8
        config.title = assistant.digest?.headline
            ?? (assistant.phase == .working ? "Summarizing your note…" : "No summary yet")
        config.titleLineBreakMode = .byTruncatingTail
        bar.configuration = config
    }

    private func showPaneSheet() {
        present(AssistantViewController(assistant: assistant), animated: true)
    }
}

/// The pane itself, in the arrangement or in a sheet. Both read the same model.
@available(iOS 27.0, *)
final class AssistantViewController: UIViewController {
    private let assistant: AssistantModel
    private let headline = UILabel()
    private let points = UILabel()
    private let status = UILabel()

    init(assistant: AssistantModel) {
        self.assistant = assistant
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        headline.font = .preferredFont(forTextStyle: .title3)
        points.numberOfLines = 0
        status.textColor = .secondaryLabel
        let stack = UIStackView(arrangedSubviews: [headline, points, status])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
        ])
    }

    override func updateProperties() {
        super.updateProperties()
        headline.text = assistant.digest?.headline
        points.text = (assistant.digest?.points ?? []).map { "• \($0)" }.joined(separator: "\n")
        switch assistant.phase {
        case .working: status.text = "Summarizing your note…"
        case .failed(let message): status.text = message
        case .idle, .done: status.text = nil
        }
    }
}
```

- Add Stop and Retry to `AssistantViewController` as buttons that call `stop()` and `retry()`; they are left out here to keep it short.
- Create the `AssistantModel` in the scene delegate or the root view controller, and hand it down. If a child controller owned it and your code replaced that child on a trait change, the stream would go with it; `duo-continuity` says never replace children there.
- Make `NoteScreenController` the root of your `UINavigationController`. The arrangement then sits inside the navigation controller, as Apple asks (`duo-layout`).
- `UIButton.Configuration.titleLineBreakMode` (iOS 15) truncates a long headline. *Unverified:* that it keeps the bar to one line at the largest text sizes; check with Dynamic Type (`duo-accessibility`).
