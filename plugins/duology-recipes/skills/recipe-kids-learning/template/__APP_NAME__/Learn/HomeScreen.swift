import SwiftUI

/// The first screen: a welcome with the stars so far, and one big card per activity.
/// Closed, the welcome sits above the cards. Open, it takes the left page and the cards
/// the right; in tabletop the cards sit below the fold, on the half that rests on the table.
/// The Grown-ups button is in the bar, away from the cards.
struct HomeScreen: View {
    let store: LearningStore

    @State private var fold = FoldGeometry()
    @State private var size = CGSize.zero
    @ScaledMetric(relativeTo: .title2) private var cardHeight = 104.0
    @ScaledMetric(relativeTo: .title2) private var iconSize = 64.0
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        PaneSplit(fold: fold, firstShare: 0.3) {
            welcome
            cards
        }
        .onFoldChange { fold = $0 }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .foldMarker(fold)
        .background(Color(.systemBackground))
        .navigationTitle("Activities")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Grown-ups", systemImage: "lock.fill") { store.openGate() }
                    .accessibilityHint("Asks a grown-up's question first")
                    .accessibilityIdentifier("home.grownups")
            }
        }
        .testMarker("home.state", value: testSummary)
    }

    private var welcome: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 72, maxHeight: 72)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Let's learn!")
                .font(.largeTitle.bold())
                .minimumScaleFactor(0.5)
                .accessibilityAddTraits(.isHeader)
            Label {
                Text(starsText(store.progress.stars))
            } icon: {
                Image(systemName: "star.fill").foregroundStyle(.yellow)
            }
                .font(.title2.bold())
                .minimumScaleFactor(0.5)
                .accessibilityIdentifier("home.stars")
        }
        .padding(16)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .frameMarker("home.welcomePane")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome")
        .accessibilityIdentifier("home.welcome")
    }

    private var cards: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(store.activities) { activity in
                    Button { store.open(activity) } label: { card(activity) }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(activity.title)
                        .accessibilityValue("\(store.progress.stars(in: activity)) of \(activity.questions.count) stars")
                        .accessibilityIdentifier("activity.\(activity.id)")
                }
            }
            .padding(16)
        }
        .frameMarker("home.cardsPane")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Activities")
        .accessibilityIdentifier("home.activities")
    }

    private func card(_ activity: Activity) -> some View {
        let stars = store.progress.stars(in: activity)
        let icon = min(iconSize, 88)
        // At accessibility text sizes the card stacks, so the title and the stars get the width.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 16))
        return layout {
            Image(systemName: activity.symbol)
                .resizable()
                .scaledToFit()
                .padding(icon * 0.2)
                .frame(width: icon, height: icon)
                .foregroundStyle(.white)
                .background(Circle().fill(activity.tint.color))
            VStack(alignment: .leading, spacing: 6) {
                Text(activity.title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    ForEach(activity.questions.indices, id: \.self) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .foregroundStyle(index < stars ? Color.yellow : Color.secondary)
                    }
                }
                .font(.title3)
            }
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.secondarySystemBackground)))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func starsText(_ count: Int) -> String {
        count == 1 ? "1 star" : "\(count) stars"
    }

    private var testSummary: String {
        let layout = LessonLayout(size: size, fold: fold, firstShare: 0.3)
        return "stars=\(store.progress.stars)|mode=\(layout.mode.rawValue)|folded=\(fold.isActive ? 1 : 0)|"
            + "size=\(Int(size.width))x\(Int(size.height))|fold=\(fold.markerText)|"
    }
}
