import UserNotifications
import Observation
import OSLog

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
            Logger.notifications.error("Notification permission request failed: \(error.localizedDescription)")
        }
    }

    private var canSchedule: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral
    }

    /// iOS allows at most 64 pending notifications per app. We cap renewal
    /// reminders below that to leave headroom for immediate price-change alerts.
    private static let reminderLimit = 60

    /// Computes when the day-before reminder should fire for a renewal.
    ///
    /// Normally the day before the renewal at 09:00 local time. If that moment
    /// has already passed (the subscription was added late, or renews very soon)
    /// but the renewal is still upcoming, it falls back to a near-term reminder
    /// so the user is still warned instead of getting nothing. Returns `nil`
    /// only when the renewal itself is not in the future.
    ///
    /// Pure and deterministic (inject `now`/`calendar`) so it can be unit-tested.
    static func reminderFireDate(
        forRenewal renewalDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard renewalDate > now else { return nil }

        let dayBefore = calendar.date(byAdding: .day, value: -1, to: renewalDate) ?? renewalDate
        var components = calendar.dateComponents([.year, .month, .day], from: dayBefore)
        components.hour = 9
        components.minute = 0
        let nineAM = calendar.date(from: components) ?? dayBefore

        if nineAM > now { return nineAM }

        // The day-before 09:00 slot has passed; warn soon, as long as the
        // renewal hasn't already arrived in the meantime.
        let soon = now.addingTimeInterval(60)
        return soon < renewalDate ? soon : nil
    }

    func scheduleAll(for subscriptions: [Subscription]) {
        guard canSchedule else {
            Logger.notifications.info("Skipping reminder scheduling: not authorised (status \(self.authorizationStatus.rawValue)).")
            return
        }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let upcoming = subscriptions
            .filter { Self.reminderFireDate(forRenewal: $0.nextRenewalDate) != nil }
            .sorted { $0.nextRenewalDate < $1.nextRenewalDate }

        if upcoming.count > Self.reminderLimit {
            Logger.notifications.warning("\(upcoming.count) renewals need reminders but iOS caps pending notifications; scheduling the soonest \(Self.reminderLimit).")
        }
        for sub in upcoming.prefix(Self.reminderLimit) { schedule(for: sub) }
        Logger.notifications.info("Scheduled \(min(upcoming.count, Self.reminderLimit)) renewal reminders.")
    }

    func schedule(for subscription: Subscription) {
        guard canSchedule else { return }
        guard let fireDate = Self.reminderFireDate(forRenewal: subscription.nextRenewalDate) else { return }

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

        // Interval trigger from the resolved fire date: avoids the past-date
        // pitfall of a calendar trigger and fires reliably for imminent renewals.
        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
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
