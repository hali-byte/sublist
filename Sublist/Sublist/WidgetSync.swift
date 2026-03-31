import WidgetKit

func updateWidgetSnapshot(from subscriptions: [Subscription], currency: String) {
    guard let defaults = UserDefaults(suiteName: AppConstants.appGroupID) else { return }
    guard let sub = subscriptions.first else {
        defaults.removeObject(forKey: AppConstants.widgetSnapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
        return
    }
    if let data = try? JSONEncoder().encode(SubscriptionSnapshot(
        name: sub.name,
        emoji: sub.emoji,
        iconName: bundledIconName(for: sub.name),
        amount: sub.amount,
        billingCycle: sub.billingCycle.rawValue,
        nextRenewalDate: sub.nextRenewalDate,
        currency: currency
    )) {
        defaults.set(data, forKey: AppConstants.widgetSnapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
