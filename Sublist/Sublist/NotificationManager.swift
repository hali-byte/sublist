import UserNotifications
import Foundation

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func scheduleAll(for subscriptions: [Subscription]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for sub in subscriptions {
            schedule(for: sub)
        }
    }

    func schedule(for subscription: Subscription) {
        guard let fireDate = Calendar.current.date(byAdding: .day, value: -1, to: subscription.nextRenewalDate),
              fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Subscription Renewing Tomorrow"
        content.body = "\(subscription.emoji) \(subscription.name) renews tomorrow for \(subscription.amount.formatted(.currency(code: "USD")))"
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: subscription.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func cancel(for subscription: Subscription) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [subscription.id.uuidString])
    }
}
