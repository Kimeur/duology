import SwiftUI
import UIKit

/// Cook mode: one step at a time, with a timer for steps that need one.
struct CookScreen: View {
    let recipe: Recipe
    @State private var index = 0
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var step: Recipe.Step { recipe.steps[index] }

    var body: some View {
        Group {
            if sizeClass == .regular {
                HStack(spacing: 0) {
                    StepCard(step: step, number: index + 1, total: recipe.steps.count)
                        .frame(width: UIScreen.main.bounds.width / 2)
                    TimerPanel(step: step)
                        .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 24) {
                    StepCard(step: step, number: index + 1, total: recipe.steps.count)
                    TimerPanel(step: step)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.bottom, 96)
        .overlay(alignment: .bottom) {
            StepControls(index: $index, count: recipe.steps.count)
                .padding(.bottom, 16)
        }
    }
}

struct StepCard: View {
    let step: Recipe.Step
    let number: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Step \(number) of \(total)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(step.title)
                .font(.largeTitle.bold())
            Text(step.text)
                .font(.title3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
}

struct TimerPanel: View {
    let step: Recipe.Step
    @StateObject private var timer = CookTimer()

    var body: some View {
        VStack(spacing: 16) {
            if step.minutes != nil {
                Text(timeText)
                    .font(.system(.largeTitle, design: .rounded).monospacedDigit().bold())
                Button(timer.isRunning ? "Pause Timer" : "Start Timer",
                       systemImage: timer.isRunning ? "pause.fill" : "play.fill") {
                    timer.toggle()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("cook.timer")
            } else {
                Label("No timer for this step", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .onAppear { timer.set(minutes: step.minutes ?? 0) }
        .onChange(of: step.id) { _, _ in timer.set(minutes: step.minutes ?? 0) }
    }

    private var timeText: String {
        String(format: "%d:%02d", timer.secondsLeft / 60, timer.secondsLeft % 60)
    }
}

struct StepControls: View {
    @Binding var index: Int
    let count: Int

    var body: some View {
        HStack(spacing: 16) {
            Button("Previous", systemImage: "chevron.backward") { index -= 1 }
                .disabled(index == 0)
                .accessibilityIdentifier("cook.previous")
            Button("Next", systemImage: "chevron.forward") { index += 1 }
                .disabled(index == count - 1)
                .accessibilityIdentifier("cook.next")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .padding(12)
        .background(.regularMaterial, in: Capsule())
    }
}
