import UserNotifications
import Observation

@Observable
final class NotificationManager {
    static let shared = NotificationManager()

    static let renewalCategoryID = "RENEWAL_REMINDER"
    static let markRenewedActionID = "MARK_RENEWED"

    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {
        registerCategories()
        Task { await refreshStatus() }
    }

    private func registerCategories() {
        let markRenewed = UNNotificationAction(
            identifier: Self.markRenewedActionID,
            title: String(localized: "Mark as Renewed", comment: "Notification action to mark subscription as renewed"),
            options: []
        )
        let renewalCategory = UNNotificationCategory(
            identifier: Self.renewalCategoryID,
            actions: [markRenewed],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([renewalCategory])
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

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
        content.title = String(localized: "Subscription Renewing Tomorrow",
                               comment: "Push notification title for day-before renewal reminder")
        let currency = UserDefaults.standard.string(forKey: AppConstants.currencyKey) ?? "USD"
        let formattedAmount = subscription.amount.formatted(.currency(code: currency))
        content.body = String(
            localized: "\(subscription.emoji) \(subscription.name) renews tomorrow for \(formattedAmount)",
            comment: "Push notification body. Parameters: emoji, subscription name, formatted price"
        )
        content.sound = .default
        content.categoryIdentifier = Self.renewalCategoryID

        var components = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: subscription.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func schedulePriceChangeNotification(for subscription: Subscription, change: PriceChangeType) {
        guard canSchedule else { return }

        let content = UNMutableNotificationContent()
        let currency = UserDefaults.standard.string(forKey: AppConstants.currencyKey) ?? "USD"

        switch change {
        case .increased(_, let new):
            content.title = String(localized: "Price Increase Detected",
                                   comment: "Push notification title for price increase")
            let formatted = new.formatted(.currency(code: currency))
            content.body = String(
                localized: "\(subscription.name) has increased to \(formatted)",
                comment: "Push notification body for price increase"
            )
        case .decreased(_, let new):
            content.title = String(localized: "Price Decrease Detected",
                                   comment: "Push notification title for price decrease")
            let formatted = new.formatted(.currency(code: currency))
            content.body = String(
                localized: "\(subscription.name) has decreased to \(formatted)",
                comment: "Push notification body for price decrease"
            )
        case .cheaperPlanAvailable(let planName, let price):
            content.title = String(localized: "Cheaper Plan Available",
                                   comment: "Push notification title for cheaper plan")
            let formatted = price.formatted(.currency(code: currency))
            content.body = String(
                localized: "\(subscription.name): \(planName) is available for \(formatted)",
                comment: "Push notification body for cheaper plan"
            )
        }

        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "priceChange_\(subscription.id.uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func cancel(for subscription: Subscription) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [subscription.id.uuidString])
    }
}
