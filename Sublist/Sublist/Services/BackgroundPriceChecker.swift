import Foundation
import SwiftData
import BackgroundTasks

@MainActor
enum BackgroundPriceChecker {
    static let taskIdentifier = "com.hugohodinka.Sublist.priceCheck"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                await handleRefresh(refreshTask)
            }
        }
    }

    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Calendar.current.date(byAdding: .day, value: 7, to: .now)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handleRefresh(_ task: BGAppRefreshTask) async {
        guard UserDefaults.standard.bool(forKey: AppConstants.backgroundPriceCheckEnabled) else {
            task.setTaskCompleted(success: true)
            return
        }

        let lastCheck = UserDefaults.standard.double(forKey: AppConstants.lastBackgroundCheckKey)
        let daysSinceLastCheck = Date.now.timeIntervalSince1970 - lastCheck
        guard daysSinceLastCheck > 6 * 24 * 3600 else {
            task.setTaskCompleted(success: true)
            scheduleNext()
            return
        }

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        do {
            let container = try ModelContainer(for: Subscription.self, PriceRecord.self)
            let context = ModelContext(container)
            let countryCode = UserDefaults.standard.string(forKey: AppConstants.countryCodeKey) ?? ""

            let code: String
            if !countryCode.isEmpty {
                code = countryCode
            } else {
                let geo = try await IPGeolocationService.shared.resolve()
                code = geo.code
            }

            let subscriptions = try context.fetch(FetchDescriptor<Subscription>())

            for subscription in subscriptions {
                guard let provider = ProviderRegistry.provider(for: subscription.name) else { continue }
                guard !Task.isCancelled else { break }

                do {
                    let plans = try await PricingService.shared.fetchPlans(for: code, using: provider)
                    if !plans.isEmpty {
                        PriceRecordService.store(
                            plans: plans,
                            serviceName: subscription.name,
                            countryCode: code,
                            subscription: subscription,
                            in: context
                        )

                        if let change = PriceChangeDetector.detectChanges(
                            for: subscription,
                            latestPlans: plans,
                            in: context
                        ) {
                            NotificationManager.shared.schedulePriceChangeNotification(
                                for: subscription,
                                change: change
                            )
                        }
                    }
                } catch {
                    continue
                }
            }

            try context.save()
            UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: AppConstants.lastBackgroundCheckKey)
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }

        scheduleNext()
    }
}
