import SwiftUI

/// The inbox. Open: the list and the selected message side by side.
/// Closed: the list pushes the message.
struct MailboxScreen: View {
    private let messages = Message.samples
    @State private var selectedID: Message.ID?
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var selected: Message? {
        messages.first { $0.id == selectedID }
    }

    var body: some View {
        if sizeClass == .regular {
            HStack(spacing: 0) {
                MessageList(messages: messages, selectedID: selectedID) { selectedID = $0 }
                    .frame(minWidth: 280, maxWidth: 360)
                Divider()
                MessagePane(message: selected ?? messages[0])
            }
        } else {
            NavigationStack(path: path) {
                MessageList(messages: messages, selectedID: selectedID) { selectedID = $0 }
                    .navigationDestination(for: Message.ID.self) { id in
                        if let message = messages.first(where: { $0.id == id }) {
                            MessagePane(message: message)
                        }
                    }
            }
        }
    }

    /// Closed, the selected message is pushed on the stack.
    private var path: Binding<[Message.ID]> {
        Binding(
            get: { selectedID.map { [$0] } ?? [] },
            set: { selectedID = $0.last }
        )
    }
}

struct MessageList: View {
    let messages: [Message]
    let selectedID: Message.ID?
    let select: (Message.ID) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Text("Inbox")
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                ForEach(messages) { message in
                    Button { select(message.id) } label: {
                        MessageRow(message: message, isSelected: message.id == selectedID)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("inbox.row.\(message.id)")
                    Divider().padding(.leading, 68)
                }
            }
        }
    }
}

struct MessageRow: View {
    let message: Message
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(message.isUnread ? Color.blue : Color.clear)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            Text(String(message.sender.prefix(1)))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.indigo))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(message.sender)
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text(message.date)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Text(message.subject)
                    .font(.system(size: 15))
                Text(message.preview)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 76)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(.rect)
    }
}

struct MessagePane: View {
    let message: Message

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(message.subject)
                    .font(.system(size: 26, weight: .bold))
                    .accessibilityIdentifier("message.subject")
                HStack(spacing: 12) {
                    Text(String(message.sender.prefix(1)))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.indigo))
                    VStack(alignment: .leading) {
                        Text(message.sender).font(.system(size: 16, weight: .semibold))
                        Text(message.date).font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    .frame(height: 40)
                }
                Text(message.body)
                    .font(.system(size: 17))
                HStack(spacing: 12) {
                    Button("Reply", systemImage: "arrowshape.turn.up.left") {}
                    Button("Archive", systemImage: "archivebox") {}
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
    }
}
