import MessageUI
import SwiftUI

struct InboxView: View {
    @Environment(Store.self) private var store

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.inbox) { message in
                    let person = store.person(message.personID)
                    HStack(alignment: .top, spacing: 12) {
                        Avatar(person: person)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(person?.name ?? "Someone").font(.headline)
                                Spacer()
                                Text(message.date, format: .relative(presentation: .named))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text("🚨 You got purposed").font(.caption.weight(.bold)).foregroundStyle(.red)
                            PhraseBubble(text: Phrases.line(from: person?.name ?? "Someone", message.phrase), outgoing: false)
                            if let reply = message.reply {
                                Label(reply, systemImage: "arrowshape.turn.up.left.fill")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else if message.repliedAt == nil {
                                HStack {
                                    if message.isOverdue(now: store.now) {
                                        Label("Not purposed back. Shameful.", systemImage: "bell.badge.fill")
                                            .font(.caption.weight(.semibold)).foregroundStyle(.red)
                                    } else {
                                        Text("Nag \(message.replyDueAt, format: .relative(presentation: .named))")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Purpose back") { store.pendingReply = message }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .overlay {
                if store.inbox.isEmpty {
                    ContentUnavailableView {
                        Label("No one has purposed you. Yet.", systemImage: "tray")
                    } description: {
                        Text("When someone purposes you, it lands here. Tap ✨ to get purposed for practice.")
                    }
                }
            }
            .navigationTitle("Inbox")
            .toolbar {
                Menu {
                    Section("Get purposed for practice (nag in 1 min)") {
                        ForEach(store.people) { person in
                            Button(person.name) { store.receiveSample(from: person) }
                        }
                        if store.people.isEmpty {
                            Button("From a random duck") { store.receiveSample(from: nil) }
                        }
                    }
                } label: {
                    Image(systemName: "sparkles")
                }
            }
        }
    }
}

struct ReplySheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let message: Message
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    Avatar(person: store.person(message.personID), size: 32)
                    PhraseBubble(text: Phrases.line(from: store.person(message.personID)?.name ?? "Someone", message.phrase), outgoing: false)
                }
                FlowRow(items: Phrases.quickReplies) { reply in
                    Button(reply) { send(reply) }.buttonStyle(.bordered)
                }
                HStack {
                    TextField("Or say something unhinged", text: $text)
                        .textFieldStyle(.roundedBorder)
                    Button { send(text) } label: { Image(systemName: "arrow.up.circle.fill").font(.title) }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Purpose back \(store.person(message.personID)?.name ?? "them")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Cancel") { dismiss() } }
        }
        .presentationDetents([.medium])
    }

    private func send(_ reply: String) {
        store.markReplied(message, reply: reply)
        dismiss()
    }
}

/// Wraps short buttons onto as many lines as they need.
struct FlowRow<Content: View>: View {
    let items: [String]
    let content: (String) -> Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack { ForEach(items, id: \.self, content: content) }
            VStack(alignment: .leading) {
                HStack { ForEach(items.prefix(2), id: \.self, content: content) }
                HStack { ForEach(items.dropFirst(2), id: \.self, content: content) }
            }
        }
    }
}

struct SendSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let request: SendRequest
    @State private var purposeID: String?
    @State private var ready = false

    var body: some View {
        if let person = store.person(request.personID) {
            if ready {
                let link = purposeID.map(Cloud.link(for:))
                TextComposer(person: person,
                             title: "Purposing \(person.name)",
                             text: Phrases.text(from: store.senderName, request.phrase,
                                                replyWindowMinutes: request.replyWindowMinutes, link: link),
                             note: link == nil ? "Couldn't reach the server, so this one goes without a link." : nil,
                             confirmLabel: "Mark as purposed ✋") { sent in
                    if sent {
                        store.recordSend(request, remoteID: purposeID)
                    } else if let purposeID {
                        Cloud.deletePurpose(purposeID)
                    }
                    dismiss()
                }
            } else {
                ProgressView("Summoning a purpose…")
                    .presentationDetents([.medium])
                    .task {
                        purposeID = try? await Cloud.createPurpose(
                            senderName: store.senderName, recipientName: person.name,
                            phrase: request.phrase, replyWindowMinutes: request.replyWindowMinutes)
                        ready = true
                    }
            }
        }
    }
}

struct NagSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let message: Message

    var body: some View {
        if let person = store.person(message.personID) {
            TextComposer(person: person,
                         title: "Nagging \(person.name)",
                         text: Phrases.nag(from: store.senderName, link: message.remoteID.map(Cloud.link(for:))),
                         note: nil,
                         confirmLabel: "Mark as nagged 🚨") { _ in dismiss() }
        }
    }
}

/// Messages' compose screen on a phone; a preview with a confirm button where texting isn't available.
struct TextComposer: View {
    let person: Person
    let title: String
    let text: String
    let note: String?
    let confirmLabel: String
    let onDone: (_ sent: Bool) -> Void

    var body: some View {
        if MFMessageComposeViewController.canSendText(), !person.phone.isEmpty {
            MessageComposeView(recipients: [person.phone], body: text) { onDone($0 == .sent) }
                .ignoresSafeArea()
        } else {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        Avatar(person: person, size: 64)
                        Text(title).font(.headline)
                        PhraseBubble(text: text)
                        Text(note ?? "This device can't send texts, so OnPurpose will just log it.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button {
                            onDone(true)
                        } label: {
                            Text(confirmLabel).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(24)
                }
                .toolbar { Button("Cancel") { onDone(false) } }
            }
            .presentationDetents([.large])
        }
    }
}

struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onFinish: (MessageComposeResult) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: (MessageComposeResult) -> Void
        init(onFinish: @escaping (MessageComposeResult) -> Void) { self.onFinish = onFinish }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            onFinish(result)
        }
    }
}
