import UserNotifications
import SwiftData

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard response.actionIdentifier == NotificationManager.markRenewedActionID else {
            completionHandler()
            return
        }

        let subscriptionIDString = response.notification.request.identifier
        guard let subscriptionID = UUID(uuidString: subscriptionIDString) else {
            completionHandler()
            return
        }

        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<Subscription>(
            predicate: #Predicate { $0.id == subscriptionID }
        )
        descriptor.fetchLimit = 1

        if let subscription = try? context.fetch(descriptor).first {
            subscription.markAsRenewed()
            try? context.save()
            NotificationManager.shared.schedule(for: subscription)
        }

        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
