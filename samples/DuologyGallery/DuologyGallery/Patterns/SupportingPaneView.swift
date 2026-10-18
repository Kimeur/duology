import SwiftUI

/// Supporting pane: an article and its discussion.
///
/// Open and held wide, the discussion sits beside the article in a narrower
/// pane. Closed, held tall or in Split View, only the article shows and a
/// toolbar button opens the same discussion in a sheet.
///
/// Built on `ArrangementView` with a horizontal-only split (iOS 27.1).
/// Pattern guide: `duo-patterns/references/supporting-pane.md`.
struct SupportingPaneView: View {
    @State private var model = DiscussionModel()
    @State private var showsSheet = false
    @State private var paneFitsBeside = false
    @Environment(\.horizontalSizeClass) private var widthClass

    var body: some View {
        NavigationStack {
            content
                .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                    // Mirrors Apple's documented split rule: side by side when wider
                    // than tall, with size class as an input. No API reports whether
                    // the secondary view is on screen, so check it in Device Hub.
                    let fits = widthClass == .regular && size.width > size.height
                    if #available(iOS 27.1, *) {
                        paneFitsBeside = fits
                    } else {
                        paneFitsBeside = false
                    }
                }
                .navigationTitle("Travel")
                .navigationBarTitleDisplayMode(.inline)
                .galleryCloseButton()
                .toolbar {
                    if !paneFitsBeside {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Discussion", systemImage: "bubble.left.and.bubble.right") {
                                showsSheet = true
                            }
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Share", systemImage: "square.and.arrow.up") {}
                    }
                }
                .sheet(isPresented: $showsSheet) {
                    NavigationStack {
                        DiscussionPane(model: model, showsHeader: false)
                            .navigationTitle("Discussion")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    .presentationDetents([.medium, .large])
                }
                .onChange(of: paneFitsBeside) { _, fits in
                    // Opened the phone with the sheet up: the pane is inline now.
                    if fits { showsSheet = false }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if #available(iOS 27.1, *) {
            // The arrangement sits inside the navigation stack, never around it.
            ArrangementView {
                ArticleBody()
            } secondary: {
                DiscussionPane(model: model, showsHeader: true)
                    // A narrower pane: a share of the width, never a point width.
                    .splitArrangementLayoutRatio(minHorizontal: 0.3, idealHorizontal: 0.36, maxHorizontal: 0.42)
            }
            // Beside, never below. When it can't sit beside, only the article shows.
            .arrangementViewStyle(.split.axes(.horizontal))
        } else {
            ArticleBody()
        }
    }
}

// MARK: - Article

private struct ArticleBody: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [Color(hex: 0x1E2A4A), Color(hex: 0x7A4CD9), Color(hex: 0xF28B54)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "tram.fill")
                        .font(.system(size: 64, weight: .regular))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    Text("TRAVEL")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(.white)
                        .padding(20)
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHidden(true)

                Text("The night train is back, and it's better than you remember")
                    .font(.largeTitle.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    InitialsAvatar(name: "Elena Ruiz", color: Color(hex: 0x7A4CD9), size: 32)
                    Text("Elena Ruiz · 6 min read · 14 October")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(Self.paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(.body)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    static let paragraphs = [
        "At ten past nine the platform is quiet. A conductor checks names against a printed list, and a family of four argues gently about who gets the top bunk. Nobody is in a hurry. That is the point.",
        "Ten years ago most sleeper routes in Europe were losing money and closing one by one. Cheap flights had taken their passengers, and the old carriages were tired. Now new lines open every season, and the trains on them are booked weeks ahead.",
        "The new cabins are small but clever. A seat folds into a bed in one move. There is a reading light that doesn't wake the person below you, a socket that works, and a window blind that actually closes.",
        "The real luxury is time you don't have to manage. You board after dinner, sleep through three countries, and wake up in a city centre with the whole day ahead. No security line, no transfer bus, no hotel for the first night.",
        "It isn't perfect. Delays still happen, the dining car closes early, and a light sleeper will feel every set of points. But for trips under a thousand kilometres, it is now a real choice, not a nostalgic one.",
        "Book early, pick a lower bunk if you can, and bring earplugs. Then put your phone away and watch the lights of small towns slide past the window."
    ]
}

// MARK: - Discussion

/// One model for the pane, inline or in a sheet, so a draft survives opening the phone.
@Observable
final class DiscussionModel {
    var comments = Comment.samples
    var draft = ""

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        comments.append(Comment(id: (comments.map(\.id).max() ?? 0) + 1, author: "You",
                                color: Color(hex: 0x2B55C7), time: "now", text: text, likes: 0))
        draft = ""
    }
}

struct Comment: Identifiable, Hashable {
    let id: Int
    var author: String
    var color: Color
    var time: String
    var text: String
    var likes: Int

    static let samples = [
        Comment(id: 1, author: "Henrik Dahl", color: Color(hex: 0x0F8A6A), time: "2h",
                text: "Took the Vienna to Hamburg sleeper in May. Best night of sleep I had all trip, which I did not expect.", likes: 24),
        Comment(id: 2, author: "Amara Nwosu", color: Color(hex: 0xC2410C), time: "2h",
                text: "The lower bunk tip is real. Climbing down a ladder at 3 a.m. is not.", likes: 17),
        Comment(id: 3, author: "Luca Ferri", color: Color(hex: 0x2B55C7), time: "1h",
                text: "Prices are the problem for families. Four berths cost more than four flights on most routes I checked.", likes: 12),
        Comment(id: 4, author: "Elena Ruiz", color: Color(hex: 0x7A4CD9), time: "1h",
                text: "Fair point, Luca. Some operators now sell a whole cabin at one price. It's worth comparing.", likes: 9),
        Comment(id: 5, author: "Noor Haddad", color: Color(hex: 0xC0266D), time: "40m",
                text: "Bring a small bag for the cabin and leave the big one in the luggage rack. There is no room for both.", likes: 6),
        Comment(id: 6, author: "Pieter de Vries", color: Color(hex: 0x5B6B7F), time: "12m",
                text: "Waking up to mountains outside the window never gets old.", likes: 3)
    ]
}

private struct DiscussionPane: View {
    @Bindable var model: DiscussionModel
    var showsHeader: Bool

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                HStack {
                    Text("Discussion")
                        .font(.headline)
                    Text("\(model.comments.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                Divider()
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(model.comments) { comment in
                        CommentRow(comment: comment)
                    }
                }
                .padding(16)
            }
            .defaultScrollAnchor(.top)
            Divider()
            HStack(spacing: 10) {
                TextField("Add to the discussion", text: $model.draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onSubmit { model.send() }
                Button("Send", systemImage: "arrow.up.circle.fill") { model.send() }
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
        }
        .background(Color(.secondarySystemBackground))
    }
}

private struct CommentRow: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            InitialsAvatar(name: comment.author, color: comment.color, size: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.author).font(.subheadline.weight(.semibold))
                    Text(comment.time).font(.footnote).foregroundStyle(.secondary)
                }
                Text(comment.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Label("\(comment.likes)", systemImage: "heart")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
