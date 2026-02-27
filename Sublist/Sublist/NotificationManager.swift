import UserNotifications
import Observation

@Observable
final class NotificationManager {
    static let shared = NotificationManager()

    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {
        Task { await refreshStatus() }
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Call this only when the user has explicitly opted in from the Settings screen.
    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            authorizationStatus = granted ? .authorized : .denied
        } catch {
            print("Notification permission error: \(error)")
        }
    }

    private var canSchedule: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral
    }

    func scheduleAll(for subscriptions: [Subscription]) {
        guard canSchedule else { return }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for sub in subscriptions { schedule(for: sub) }
    }

    func schedule(for subscription: Subscription) {
        guard canSchedule else { return }
        guard let fireDate = Calendar.current.date(byAdding: .day, value: -1, to: subscription.nextRenewalDate),
              fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Subscription Renewing Tomorrow"
        let currency = UserDefaults.standard.string(forKey: "currency") ?? "USD"
        content.body = "\(subscription.emoji) \(subscription.name) renews tomorrow for \(subscription.amount.formatted(.currency(code: currency)))"
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
