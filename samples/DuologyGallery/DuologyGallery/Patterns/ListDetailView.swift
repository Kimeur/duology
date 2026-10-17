import SwiftUI

/// List-detail: an inbox.
///
/// Closed, the split view collapses to one stack: the list, then the message.
/// Open and held wide, list and message sit side by side. Partly folded like a
/// book, the system evens the columns out to one per side of the fold. Held
/// tall (tabletop), the list starts over the detail column when nothing is
/// selected. No Duo-only API is needed.
///
/// Pattern guide: `duo-patterns/references/list-detail.md`.
struct ListDetailView: View {
    // Selection lives above the split view, so fold, unfold and rotation keep it.
    // Scene storage also brings it back after the system ends the app.
    @SceneStorage("inbox.selection") private var selection: Int?
    // Which column a collapsed split view (the outer display) shows on top.
    @State private var compactColumn = NavigationSplitViewColumn.sidebar
    // Both columns when the split view expands with nothing to show. Without
    // this, the open phone held tall (tabletop) hides the list and shows only
    // the placeholder. Held tall, the list then sits over the detail column.
    // Launched with a message (`-select`), the system chooses: held tall, the
    // message alone; held wide, list and message side by side.
    @State private var columnVisibility: NavigationSplitViewVisibility =
        LaunchOptions.selection == nil ? .all : .automatic
    @State private var messages = MailMessage.samples
    @State private var showsUnreadOnly = false

    private var visibleMessages: [MailMessage] {
        showsUnreadOnly ? messages.filter(\.isUnread) : messages
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $compactColumn) {
            List(visibleMessages, selection: $selection) { message in
                MessageRow(message: message)
                    .tag(message.id)
            }
            .listStyle(.plain)
            .navigationTitle("Inbox")
            .galleryCloseButton()
            .toolbar {
                // List actions stay with the list column. In a split view only the
                // detail column's bar goes vertical on iPhone Duo.
                ToolbarItem(placement: .primaryAction) {
                    Toggle(isOn: $showsUnreadOnly) {
                        Label("Unread Only", systemImage: "line.3.horizontal.decrease")
                    }
                    .toggleStyle(.button)
                }
            }
        } detail: {
            if let index = messages.firstIndex(where: { $0.id == selection }) {
                MessageDetail(message: $messages[index])
            } else {
                // Open with nothing selected: a placeholder, never an empty pane.
                NoMessageSelected()
            }
        }
        .onChange(of: selection) { _, newValue in
            // Opening a message marks it read, in every layout.
            if let index = messages.firstIndex(where: { $0.id == newValue }) {
                messages[index].isUnread = false
            }
        }
        .task {
            if selection == nil, let preset = LaunchOptions.selection {
                selection = preset
            }
        }
    }
}

/// The detail placeholder. Centred, except when the phone is partly folded
/// across (tabletop): then it sits above the fold, so its text never lands in it.
private struct NoMessageSelected: View {
    @State private var fold = FoldGeometry()

    var body: some View {
        GeometryReader { proxy in
            let area = placeholderArea(in: proxy.size)
            ContentUnavailableView(
                "No Message Selected",
                systemImage: "envelope.open",
                description: Text("Pick a message from the list.")
            )
            .frame(width: area.width, height: area.height)
            .position(x: area.midX, y: area.midY)
        }
        .onFoldChange { fold = $0 }
    }

    private func placeholderArea(in size: CGSize) -> CGRect {
        let whole = CGRect(origin: .zero, size: size)
        guard fold.isActive, !fold.isVertical, let frame = fold.frame else { return whole }
        return CGRect(x: 0, y: 0, width: size.width, height: max(0, frame.minY))
    }
}

private struct MessageRow: View {
    let message: MailMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            InitialsAvatar(name: message.sender, color: message.color, size: 42)
                .overlay(alignment: .topLeading) {
                    if message.isUnread {
                        Circle()
                            .fill(.tint)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                            .offset(x: -2, y: -2)
                            .accessibilityLabel("Unread")
                    }
                }
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(message.sender)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(message.date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(message.subject)
                    .font(.subheadline.weight(message.isUnread ? .semibold : .regular))
                    .lineLimit(1)
                Text(message.preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MessageDetail: View {
    @Binding var message: MailMessage
    @State private var confirmsDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(message.subject)
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    InitialsAvatar(name: message.sender, color: message.color, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(message.sender).font(.headline)
                        Text("To: Studio team").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(message.date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                ForEach(message.body, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(.body)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let attachment = message.attachment {
                    Label(attachment, systemImage: "doc.richtext")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(message.sender)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Item actions belong to the detail column. On iPhone Duo they can
            // move to the vertical bar on the side.
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Reply", systemImage: "arrowshape.turn.up.left") {}
                Button(message.isFlagged ? "Unflag" : "Flag",
                       systemImage: message.isFlagged ? "flag.slash" : "flag") {
                    message.isFlagged.toggle()
                }
                Button("Archive", systemImage: "archivebox") {}
                Button("Delete", systemImage: "trash", role: .destructive) {
                    confirmsDelete = true
                }
            }
        }
        // System dialogs move off the fold on their own.
        .confirmationDialog("Delete this message?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete Message", role: .destructive) {}
        }
    }
}

// MARK: - Sample data

struct MailMessage: Identifiable, Hashable {
    let id: Int
    var sender: String
    var color: Color
    var subject: String
    var preview: String
    var body: [String]
    var date: String
    var attachment: String?
    var isUnread = false
    var isFlagged = false

    static let samples: [MailMessage] = [
        MailMessage(
            id: 1, sender: "Maya Okafor", color: Color(hex: 0x2B55C7),
            subject: "Venue confirmed for the October offsite",
            preview: "Good news: the boathouse said yes for the 28th. They can seat all fourteen of us and the kitchen opens at noon.",
            body: [
                "Good news: the boathouse said yes for the 28th. They can seat all fourteen of us, and the kitchen opens at noon, so lunch is easy.",
                "I booked the long room upstairs for the morning session. It has two screens and a whiteboard wall. If we split into groups after lunch, the terrace is ours too.",
                "Could everyone send me dietary needs by Friday? I'll share the full plan, with train times, next week."
            ],
            date: "9:41", attachment: "Offsite plan.pdf", isUnread: true
        ),
        MailMessage(
            id: 2, sender: "Leo Brandt", color: Color(hex: 0x0F8A6A),
            subject: "Notes from Thursday's usability session",
            preview: "Five people, forty minutes each. The big one: nobody found the export button once the toolbar moved to the side.",
            body: [
                "Five people, forty minutes each. Recordings are in the shared folder.",
                "The big one: nobody found the export button once the toolbar moved to the side. Three people looked for it at the bottom of the screen first. I think we lost it to the overflow menu.",
                "Smaller things: the empty state on the detail pane read as an error to two people, and the search field was hard to reach with a thumb on the big screen.",
                "Happy to walk through the clips on Monday."
            ],
            date: "8:15", isUnread: true
        ),
        MailMessage(
            id: 3, sender: "Northline Rail", color: Color(hex: 0x7A4CD9),
            subject: "Your ticket: Paris to Milan, 24 October",
            preview: "Departure 07:12 from Gare de Lyon, coach 6, seat 64. Your ticket is attached and works offline.",
            body: [
                "Departure 07:12 from Gare de Lyon, arriving Milano Centrale at 14:20.",
                "Coach 6, seat 64, window, facing forward. Your ticket is attached and works offline. Show the code on your phone when asked.",
                "You can change this ticket for free until two hours before departure."
            ],
            date: "Yesterday", attachment: "Ticket NR-48213.pdf"
        ),
        MailMessage(
            id: 4, sender: "Priya Raman", color: Color(hex: 0xC2410C),
            subject: "Draft Q4 roadmap, comments by Wednesday",
            preview: "Here's the first pass. I cut the sync rewrite to make room for the two-pane layouts. Tell me if that's wrong.",
            body: [
                "Here's the first pass at the Q4 roadmap.",
                "I cut the sync rewrite to make room for the two-pane layouts. The sync work matters, but nobody outside the team will see it this quarter, and the new layouts ship with the holiday release.",
                "Please leave comments in the doc by Wednesday. We'll lock it on Thursday morning."
            ],
            date: "Yesterday", attachment: "Q4 roadmap draft", isFlagged: true
        ),
        MailMessage(
            id: 5, sender: "Sofia Marin", color: Color(hex: 0xC0266D),
            subject: "Photos from the ridge walk",
            preview: "Uploaded about sixty. The one of the fog rolling over the second saddle is my favourite. Take any you like.",
            body: [
                "Uploaded about sixty to the shared album. The one of the fog rolling over the second saddle is my favourite.",
                "Take any you like for the newsletter. Credit isn't needed, but a mention of the trail club would be nice."
            ],
            date: "Tuesday"
        ),
        MailMessage(
            id: 6, sender: "Tomás Ibarra", color: Color(hex: 0x0E7490),
            subject: "Can we move our one-on-one?",
            preview: "Something came up on Thursday afternoon. Would Friday at 10 work instead? Same room, or a walk if it's dry.",
            body: [
                "Something came up on Thursday afternoon. Would Friday at 10 work instead?",
                "Same room, or a walk around the park if it's dry. I'd like to talk about the design review process."
            ],
            date: "Tuesday"
        ),
        MailMessage(
            id: 7, sender: "Ana Lindqvist", color: Color(hex: 0x3F7D20),
            subject: "Invoice 2026-114 is paid",
            preview: "Thanks, the transfer arrived this morning. A receipt is attached for your records.",
            body: [
                "Thanks, the transfer arrived this morning.",
                "A receipt is attached for your records. I'll send the November invoice at the start of next month."
            ],
            date: "Monday", attachment: "Receipt 2026-114.pdf"
        ),
        MailMessage(
            id: 8, sender: "Hillside Garden Club", color: Color(hex: 0xD9480F),
            subject: "Harvest day this Saturday",
            preview: "Bring gloves and a bag. We start at nine with the squash beds, then soup at the shed around noon.",
            body: [
                "Bring gloves and a bag. We start at nine with the squash beds and the last of the beans.",
                "Soup at the shed around noon. If you can bring bread, reply to this message so we don't end up with eight loaves again."
            ],
            date: "Sunday"
        ),
        MailMessage(
            id: 9, sender: "Jonas Weber", color: Color(hex: 0x5B6B7F),
            subject: "Re: Type scale for the large display",
            preview: "Agreed on 17 for body. I'd keep the headline steps the same and let the extra room go to margins, not bigger text.",
            body: [
                "Agreed on 17 for body text.",
                "I'd keep the headline steps the same on both displays and let the extra room go to margins and a second column, not bigger text. Otherwise the open phone just looks like a zoomed-in closed phone."
            ],
            date: "Sunday"
        )
    ]
}
