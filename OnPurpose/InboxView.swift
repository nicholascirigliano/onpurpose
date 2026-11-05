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

    private var fullText: String {
        Phrases.text(from: store.senderName, request.phrase, replyWindowMinutes: request.replyWindowMinutes)
    }

    var body: some View {
        let person = store.person(request.personID)
        if MFMessageComposeViewController.canSendText(), let phone = person?.phone, !phone.isEmpty {
            MessageComposeView(recipients: [phone], body: fullText) { result in
                if result == .sent { store.recordSend(request) }
                dismiss()
            }
            .ignoresSafeArea()
        } else {
            NavigationStack {
                VStack(spacing: 20) {
                    Avatar(person: person, size: 64)
                    Text("Purposing \(person?.name ?? "them")").font(.headline)
                    PhraseBubble(text: fullText)
                    Text("This device can't send texts, so OnPurpose will just log it as purposed.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button {
                        store.recordSend(request)
                        dismiss()
                    } label: {
                        Text("Mark as purposed ✋").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(24)
                .toolbar { Button("Cancel") { dismiss() } }
            }
            .presentationDetents([.medium, .large])
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
