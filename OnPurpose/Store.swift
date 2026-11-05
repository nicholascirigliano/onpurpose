import Foundation
import Observation

enum Tab: Hashable { case today, people, inbox }

@Observable
final class Store {
    static let shared = Store()

    var people: [Person] = []
    var plans: [SendPlan] = []
    var messages: [Message] = []

    /// Signs every outgoing purpose: "<myName> wants you to …".
    var myName: String = UserDefaults.standard.string(forKey: "myName") ?? "" {
        didSet { UserDefaults.standard.set(myName, forKey: "myName") }
    }
    var senderName: String {
        let name = myName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Someone" : name
    }

    var tab: Tab = .today
    var pendingSend: SendRequest?
    var pendingReply: Message?
    /// Ticked by a timer so due/overdue states refresh while the app is open.
    var now = Date()

    private struct Snapshot: Codable {
        var people: [Person]
        var plans: [SendPlan]
        var messages: [Message]
    }

    private let fileURL = URL.documentsDirectory.appending(path: "onpurpose.json")

    init() { load() }

    // MARK: Lookups

    func person(_ id: UUID) -> Person? { people.first { $0.id == id } }
    func plans(for person: Person) -> [SendPlan] { plans.filter { $0.personID == person.id } }
    func messages(for person: Person) -> [Message] {
        messages.filter { $0.personID == person.id }.sorted { $0.date > $1.date }
    }

    var duePlans: [SendPlan] { plans.filter { $0.isDue(now: now) } }

    var upcoming: [(plan: SendPlan, date: Date)] {
        plans.compactMap { plan in
            guard plan.isActive, !plan.isDue(now: now), let next = plan.nextOccurrence(after: now) else { return nil }
            return (plan, next)
        }
        .sorted { $0.date < $1.date }
    }

    var awaitingReply: [Message] {
        messages.filter { $0.direction == .sent && $0.repliedAt == nil }.sorted { $0.date > $1.date }
    }

    var inbox: [Message] {
        messages.filter { $0.direction == .received }.sorted {
            ($0.repliedAt == nil) != ($1.repliedAt == nil) ? $0.repliedAt == nil : $0.date > $1.date
        }
    }

    var unrepliedCount: Int { inbox.filter { $0.repliedAt == nil }.count }

    // MARK: People and plans

    func save(_ person: Person) {
        upsert(person, into: &people)
        persist()
    }

    func delete(_ person: Person) {
        for m in messages where m.personID == person.id { Scheduler.cancelReplyReminder(for: m.id) }
        people.removeAll { $0.id == person.id }
        plans.removeAll { $0.personID == person.id }
        messages.removeAll { $0.personID == person.id }
        persist()
        reschedule()
    }

    func save(_ plan: SendPlan) {
        upsert(plan, into: &plans)
        persist()
        reschedule()
    }

    func delete(_ plan: SendPlan) {
        plans.removeAll { $0.id == plan.id }
        persist()
        reschedule()
    }

    // MARK: Messages

    func recordSend(_ request: SendRequest) {
        messages.append(Message(personID: request.personID, phrase: request.phrase,
                                direction: .sent, replyWindowMinutes: request.replyWindowMinutes))
        if let planID = request.planID, let i = plans.firstIndex(where: { $0.id == planID }) {
            plans[i].lastSentAt = .now
            if plans[i].repeatRule == .once { plans[i].isActive = false }
        }
        persist()
        reschedule()
    }

    func markReplied(_ message: Message, reply: String? = nil) {
        guard let i = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[i].repliedAt = .now
        messages[i].reply = reply
        Scheduler.cancelReplyReminder(for: message.id)
        persist()
    }

    /// Stands in for a friend's message arriving until there's a backend.
    func receiveSample(from person: Person?, replyWindowMinutes: Int = 1) {
        let sender = person ?? {
            let p = Person(name: "Alex", phone: "", emoji: "🦆")
            save(p)
            return p
        }()
        let message = Message(personID: sender.id, phrase: Phrases.all.randomElement()!,
                              direction: .received, replyWindowMinutes: replyWindowMinutes)
        messages.append(message)
        persist()
        Scheduler.scheduleReplyReminder(for: message, from: sender)
    }

    // MARK: Notifications

    func handleNotification(_ info: [AnyHashable: Any]) {
        if let id = (info["planID"] as? String).flatMap(UUID.init),
           let plan = plans.first(where: { $0.id == id }) {
            tab = .today
            pendingSend = SendRequest(personID: plan.personID, phrase: plan.phrase,
                                      replyWindowMinutes: plan.replyWindowMinutes, planID: plan.id)
        } else if let id = (info["messageID"] as? String).flatMap(UUID.init),
                  let message = messages.first(where: { $0.id == id }) {
            tab = .inbox
            if message.repliedAt == nil { pendingReply = message }
        }
    }

    func reschedule() { Scheduler.syncSendReminders(plans: plans, people: people) }

    // MARK: Persistence

    private func upsert<T: Identifiable>(_ item: T, into list: inout [T]) {
        if let i = list.firstIndex(where: { $0.id == item.id }) { list[i] = item } else { list.append(item) }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        people = snap.people
        plans = snap.plans
        messages = snap.messages
    }

    private func persist() {
        let snap = Snapshot(people: people, plans: plans, messages: messages)
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
