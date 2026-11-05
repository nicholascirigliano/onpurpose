import Foundation

/// A "phrase" is the thing you want them to do: "Nick wants you to <phrase> on purpose ✋".
enum Phrases {
    static let all = [
        "have a good day",
        "drink a glass of water",
        "touch grass",
        "eat a vegetable",
        "parallel park flawlessly",
        "not reply-all to anything",
        "have a mediocre-to-good week",
        "crush it",
    ]

    static let quickReplies = [
        "Consider me purposed ✋",
        "Purposing you right back 🫵",
        "I accept this purpose begrudgingly",
        "Who gave you this power",
    ]

    static func line(from sender: String, _ phrase: String) -> String {
        "\(sender) wants you to \(phrase) on purpose ✋"
    }

    /// The full chain text that goes out over Messages.
    static func text(from sender: String, _ phrase: String, replyWindowMinutes: Int) -> String {
        """
        🚨 YOU GOT PURPOSED 🚨

        \(line(from: sender, phrase))

        Purpose them back within \(ReplyWindow.label(replyWindowMinutes)) or face mild consequences.
        """
    }
}

struct Person: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var phone: String
    var emoji: String = "🤠"

    static let emojis = ["🤠", "🐸", "🦆", "🥸", "🗿", "🌮", "🦖", "🤡", "😎", "🫡"]
}

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case once, daily, weekdays, weekly
    var id: String { rawValue }

    var label: String {
        switch self {
        case .once: "Once"
        case .daily: "Daily"
        case .weekdays: "Weekdays"
        case .weekly: "Weekly"
        }
    }
}

enum ReplyWindow {
    /// Minutes → label. The 1-minute option makes it easy to try the reminder.
    static let options: [(minutes: Int, label: String)] = [
        (1, "1 minute (try it)"),
        (60, "1 hour"),
        (180, "3 hours"),
        (360, "6 hours"),
        (720, "12 hours"),
        (1440, "1 day"),
        (2880, "2 days"),
    ]

    static func label(_ minutes: Int) -> String {
        if minutes == 1 { return "1 minute" }
        if minutes < 60 { return "\(minutes) min" }
        if minutes == 60 { return "1 hour" }
        if minutes < 1440 { return "\(minutes / 60) hr" }
        return minutes == 1440 ? "1 day" : "\(minutes / 1440) days"
    }
}

/// A scheduled, possibly recurring, message to one person.
struct SendPlan: Identifiable, Codable, Hashable {
    var id = UUID()
    var personID: UUID
    var phrase: String = Phrases.all[0]
    var repeatRule: RepeatRule = .daily
    /// Full date for `.once`; only the time of day matters otherwise.
    var time: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    /// 1 = Sunday … 7 = Saturday, used by `.weekly`.
    var weekday: Int = Calendar.current.component(.weekday, from: .now)
    var replyWindowMinutes: Int = 180
    var isActive = true
    var createdAt = Date()
    var lastSentAt: Date?

    var scheduleText: String {
        let t = time.formatted(date: .omitted, time: .shortened)
        switch repeatRule {
        case .once: return time.formatted(.dateTime.weekday(.abbreviated).month().day().hour().minute())
        case .daily: return "Daily at \(t)"
        case .weekdays: return "Weekdays at \(t)"
        case .weekly: return "\(Calendar.current.weekdaySymbols[weekday - 1])s at \(t)"
        }
    }

    private func matches(_ date: Date, _ cal: Calendar) -> Bool {
        let wd = cal.component(.weekday, from: date)
        switch repeatRule {
        case .once: return false
        case .daily: return true
        case .weekdays: return (2...6).contains(wd)
        case .weekly: return wd == weekday
        }
    }

    private func occurrence(on day: Date, _ cal: Calendar) -> Date? {
        let hm = cal.dateComponents([.hour, .minute], from: time)
        return cal.date(bySettingHour: hm.hour ?? 8, minute: hm.minute ?? 0, second: 0, of: day)
    }

    /// The most recent scheduled moment at or before `now`.
    func latestOccurrence(before now: Date, calendar cal: Calendar = .current) -> Date? {
        if repeatRule == .once { return time <= now ? time : nil }
        for back in 0..<8 {
            guard let day = cal.date(byAdding: .day, value: -back, to: now),
                  let candidate = occurrence(on: day, cal),
                  candidate <= now, matches(candidate, cal) else { continue }
            return candidate
        }
        return nil
    }

    func nextOccurrence(after now: Date, calendar cal: Calendar = .current) -> Date? {
        if repeatRule == .once { return time > now ? time : nil }
        for ahead in 0..<8 {
            guard let day = cal.date(byAdding: .day, value: ahead, to: now),
                  let candidate = occurrence(on: day, cal),
                  candidate > now, matches(candidate, cal) else { continue }
            return candidate
        }
        return nil
    }

    /// True when a scheduled moment has passed and it hasn't been sent since.
    func isDue(now: Date) -> Bool {
        guard isActive, let occ = latestOccurrence(before: now) else { return false }
        let since = lastSentAt ?? (repeatRule == .once ? .distantPast : createdAt)
        return occ > since
    }
}

enum Direction: String, Codable { case sent, received }

struct Message: Identifiable, Codable, Hashable {
    var id = UUID()
    var personID: UUID
    var phrase: String
    var direction: Direction
    var date = Date()
    var replyWindowMinutes: Int
    var repliedAt: Date?
    var reply: String?

    var replyDueAt: Date { date.addingTimeInterval(Double(replyWindowMinutes) * 60) }
    func isOverdue(now: Date) -> Bool { repliedAt == nil && now >= replyDueAt }
}

/// What the send sheet needs, whether it came from a schedule or "Send now".
struct SendRequest: Identifiable {
    let id = UUID()
    var personID: UUID
    var phrase: String
    var replyWindowMinutes: Int
    var planID: UUID?
}
