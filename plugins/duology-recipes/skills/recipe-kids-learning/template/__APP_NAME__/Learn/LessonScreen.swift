import SwiftUI

/// One question at a time: the picture, the question and the speaker button in the first
/// pane; big answer buttons in the second.
///
/// - Closed: the two panes stacked, one question on the screen.
/// - Open and held wide, or folded like a book: the question on the left page, the
///   answers on the right one, with the fold between them.
/// - Tabletop (and open, held tall): the picture above the fold, the answers below it, on
///   the half that rests on the table.
///
/// One `PaneSplit` for every pose, so a fold never rebuilds the panes. What the child has
/// done lives in the store, so the same question, wrong tries and stars come back after any
/// fold. No timer anywhere: the child takes as long as they like.
struct LessonScreen: View {
    let activity: Activity
    let store: LearningStore

    @State private var fold = FoldGeometry()
    @State private var size = CGSize.zero
    @State private var answerSpace = CGSize.zero
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title) private var speakerSize = 88.0

    /// Grows with the text size up to 120 pt, so the question keeps the room.
    private var speakerSide: CGFloat { min(speakerSize, 120) }

    private var turn: Progress.Turn { store.progress.turn(in: activity) }
    private var question: Question? { store.progress.question(in: activity) }

    var body: some View {
        PaneSplit(fold: fold) {
            promptPane
            answersPane
        }
        .onFoldChange { fold = $0 }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .foldMarker(fold)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: turn)
        .background(Color(.systemBackground))
        .navigationTitle(activity.title)
        .navigationBarTitleDisplayMode(.inline)
        // A new question is read aloud when it appears. Not on a fold: the ID doesn't change.
        .task(id: question?.id) { readQuestionAloud() }
        .testMarker("lesson.state", value: testSummary)
    }

    // MARK: The question

    /// At accessibility text sizes the pane scrolls: the question, the speaker under it, then a
    /// picture of fixed height, so nothing is cut off. Otherwise the picture comes first and
    /// takes whatever room the text leaves. Chosen by text size, never by pose.
    private var promptPane: some View {
        Group {
            if typeSize.isAccessibilitySize {
                ScrollView { promptContent(pictureHeight: 140) }
            } else {
                promptContent(pictureHeight: nil)
            }
        }
        .padding(16)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(Color(.secondarySystemBackground)))
        .padding(8)
        .frameMarker("lesson.questionPane")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Question")
        .accessibilityIdentifier("lesson.prompt")
    }

    private func promptContent(pictureHeight: CGFloat?) -> some View {
        VStack(spacing: 12) {
            HStack {
                Spacer(minLength: 0)
                starsBadge
            }
            if let question {
                if pictureHeight == nil {
                    picture(question)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                let row = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
                row {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(question.text)
                            .font(.title.bold())
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        feedback
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    speakerButton(question)
                }
                // Large text: the question and the speaker come first, the picture under them.
                if let pictureHeight {
                    picture(question)
                        .frame(maxWidth: .infinity)
                        .frame(height: pictureHeight)
                }
            } else {
                finishedMessage
            }
        }
    }

    /// The question's picture. A group of things to count stays a container, so VoiceOver
    /// reads each one ("star", "star", "star"); anything else is one image with a label.
    @ViewBuilder
    private func picture(_ question: Question) -> some View {
        if case .group = question.art {
            ArtView(art: question.art)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(question.artLabel)
        } else {
            ArtView(art: question.art)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(question.artLabel)
                .accessibilityAddTraits(.isImage)
        }
    }

    @ViewBuilder
    private var feedback: some View {
        if turn.isSolved {
            Label(AppFacts.rightFeedback, systemImage: "hand.thumbsup.fill")
                .font(.title3.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("lesson.feedback")
        } else if !turn.wrong.isEmpty {
            Label(AppFacts.wrongFeedback, systemImage: "lightbulb.fill")
                .font(.title3.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("lesson.feedback")
        }
    }

    private func speakerButton(_ question: Question) -> some View {
        Button { store.speaker.say(question.spoken) } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: speakerSide * 0.4, weight: .bold))
                .frame(width: speakerSide, height: speakerSide)
                .foregroundStyle(.white)
                .background(Circle().fill(Color.accentColor))
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Read the question aloud")
        .accessibilityIdentifier("lesson.speaker")
    }

    private var starsBadge: some View {
        Label {
            Text("\(store.progress.stars(in: activity)) of \(activity.questions.count)")
        } icon: {
            Image(systemName: "star.fill").foregroundStyle(.yellow)
        }
        .font(.headline)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color(.systemBackground)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(store.progress.stars(in: activity)) of \(activity.questions.count) stars")
        .accessibilityIdentifier("lesson.stars")
    }

    private var finishedMessage: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 160, maxHeight: .infinity)
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)
            Text("All done!")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text("You have \(store.progress.stars(in: activity)) of \(activity.questions.count) stars.")
                .font(.title2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: The answers

    private var answersPane: some View {
        ZStack {
            if let question {
                if turn.isSolved {
                    solvedPanel
                } else {
                    TileGrid(items: question.answers, space: answerSpace) { answer, size in
                        answerButton(answer, size: size)
                    }
                }
            } else {
                TileGrid(items: EndChoice.allCases, space: answerSpace) { choice, size in
                    endButton(choice, size: size)
                }
            }
        }
        // minWidth and minHeight 0: the pane takes the size it is offered, never its buttons'
        // size, so the measured space can't feed back into the buttons and stay too wide.
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { answerSpace = $0 }
        .padding(16)
        .frameMarker("lesson.answersPane")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Answers")
        .accessibilityIdentifier("lesson.answers")
    }

    private func answerButton(_ answer: Answer, size: CGSize) -> some View {
        let triedAndWrong = turn.wrong.contains(answer.id)
        return Button { choose(answer) } label: {
            BigTile(art: answer.art, caption: answer.showsCaption ? answer.label : nil, size: size)
        }
        .buttonStyle(PressableStyle())
        .disabled(triedAndWrong)
        .opacity(triedAndWrong ? 0.35 : 1)
        .accessibilityLabel(answer.label)
        .accessibilityIdentifier("answer.\(answer.id)")
    }

    /// After a right answer: a star, a word of praise, and a big Next button in the same
    /// pane as the answers, so it stays on the side people touch.
    private var solvedPanel: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.fill")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 140, maxHeight: .infinity)
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)
            Text(AppFacts.rightFeedback)
                .font(.largeTitle.bold())
                .minimumScaleFactor(0.5)
            Button { store.next(in: activity) } label: {
                Label("Next", systemImage: "arrow.forward")
                    .font(.title.bold())
                    .frame(maxWidth: AnswerGrid.largestButton.width, minHeight: AnswerGrid.minimumTarget)
                    .foregroundStyle(.white)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.accentColor))
                    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Next question")
            .accessibilityIdentifier("lesson.next")
        }
    }

    private enum EndChoice: String, CaseIterable, Identifiable {
        case playAgain, home
        var id: String { rawValue }
    }

    private func endButton(_ choice: EndChoice, size: CGSize) -> some View {
        Button {
            switch choice {
            case .playAgain: store.playAgain(activity)
            case .home: store.path = []
            }
        } label: {
            switch choice {
            case .playAgain:
                BigTile(art: .symbol("arrow.counterclockwise", .green), caption: "Play again", size: size)
            case .home:
                BigTile(art: .symbol("house.fill", .blue), caption: "All activities", size: size)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("lesson.\(choice.rawValue)")
    }

    // MARK: Speaking

    private func choose(_ answer: Answer) {
        switch store.pick(answer, in: activity) {
        case .right: respond(AppFacts.rightFeedback)
        case .wrong: respond(AppFacts.wrongFeedback)
        case .ignored: break
        }
    }

    /// Feedback out loud: VoiceOver announces it, otherwise the speaker says it.
    private func respond(_ words: String) {
        if voiceOverOn {
            AccessibilityNotification.Announcement(words).post()
        } else if store.readsAloud {
            store.speaker.say(words)
        }
    }

    private func readQuestionAloud() {
        guard let question, !turn.isSolved, store.readsAloud, !voiceOverOn else { return }
        store.speaker.say(question.spoken)
    }

    // MARK: Test marker

    private var testSummary: String {
        let layout = LessonLayout(size: size, fold: fold)
        let grid = AnswerGrid(count: question?.answers.count ?? EndChoice.allCases.count, in: answerSpace)
        return "activity=\(activity.id)|question=\(turn.question)|of=\(activity.questions.count)|"
            + "solved=\(turn.isSolved ? 1 : 0)|wrong=\(turn.wrong.joined(separator: ","))|"
            + "finished=\(store.progress.isFinished(activity) ? 1 : 0)|stars=\(store.progress.stars)|"
            + "mode=\(layout.mode.rawValue)|folded=\(fold.isActive ? 1 : 0)|"
            + "size=\(Int(size.width))x\(Int(size.height))|fold=\(fold.markerText)|"
            + "grid=\(grid.columns)x\(grid.rows)|button=\(Int(grid.button.width))x\(Int(grid.button.height))|"
            + "said=\(store.speaker.lastRequest)|"
    }
}
