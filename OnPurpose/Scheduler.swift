import UIKit
import UserNotifications

/// Local notifications: "time to send" for schedules, and "you haven't replied" for received messages.
enum Scheduler {
    private static var center: UNUserNotificationCenter { .current() }

    static func requestPermission() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func syncSendReminders(plans: [SendPlan], people: [Person]) {
        center.getPendingNotificationRequests { requests in
            let old = requests.map(\.identifier).filter { $0.hasPrefix("plan-") }
            center.removePendingNotificationRequests(withIdentifiers: old)

            for plan in plans where plan.isActive {
                guard let person = people.first(where: { $0.id == plan.personID }) else { continue }
                let content = UNMutableNotificationContent()
                content.title = "\(person.name) is dangerously un-purposed"
                content.body = "They need to \(plan.phrase) on purpose. Only you can make this happen."
                content.sound = .default
                content.userInfo = ["planID": plan.id.uuidString]

                for (i, components) in triggerComponents(for: plan).enumerated() {
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components,
                                                                repeats: plan.repeatRule != .once)
                    center.add(UNNotificationRequest(identifier: "plan-\(plan.id)-\(i)",
                                                     content: content, trigger: trigger))
                }
            }
        }
    }

    private static func triggerComponents(for plan: SendPlan) -> [DateComponents] {
        let cal = Calendar.current
        let hm = cal.dateComponents([.hour, .minute], from: plan.time)
        func at(weekday: Int?) -> DateComponents {
            DateComponents(hour: hm.hour, minute: hm.minute, weekday: weekday)
        }
        switch plan.repeatRule {
        case .once:
            guard plan.time > .now else { return [] }
            return [cal.dateComponents([.year, .month, .day, .hour, .minute], from: plan.time)]
        case .daily: return [at(weekday: nil)]
        case .weekdays: return (2...6).map { at(weekday: $0) }
        case .weekly: return [at(weekday: plan.weekday)]
        }
    }

    static func scheduleReplyReminder(for message: Message, from person: Person) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ You still haven't purposed back"
        content.body = "\(person.name) purposed you and you left them hanging. The chain is in your hands."
        content.sound = .default
        content.userInfo = ["messageID": message.id.uuidString]

        let delay = max(message.replyDueAt.timeIntervalSinceNow, 5)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        center.add(UNNotificationRequest(identifier: "reply-\(message.id)", content: content, trigger: trigger))
    }

    static func cancelReplyReminder(for messageID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: ["reply-\(messageID)"])
        center.removeDeliveredNotifications(withIdentifiers: ["reply-\(messageID)"])
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Cloud.configure()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        DispatchQueue.main.async { Store.shared.now = .now }
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        DispatchQueue.main.async { Store.shared.handleNotification(info) }
        completionHandler()
    }
}
