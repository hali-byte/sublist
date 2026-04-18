import Foundation
import SwiftData

@MainActor
enum PriceRecordService {
    static func store(
        plans: [SubscriptionPlan],
        serviceName: String,
        countryCode: String,
        subscription: Subscription? = nil,
        in context: ModelContext
    ) {
        let now = Date()
        for plan in plans {
            let record = PriceRecord(
                serviceName: serviceName,
                planName: plan.name,
                price: NSDecimalNumber(decimal: plan.price).doubleValue,
                currency: plan.currency,
                billingPeriod: plan.billingPeriod,
                countryCode: countryCode,
                fetchDate: now,
                subscription: subscription
            )
            context.insert(record)
        }
    }

    static func latestRecords(
        for serviceName: String,
        countryCode: String,
        in context: ModelContext
    ) -> [PriceRecord] {
        var descriptor = FetchDescriptor<PriceRecord>(
            predicate: #Predicate { $0.serviceName == serviceName && $0.countryCode == countryCode },
            sortBy: [SortDescriptor(\.fetchDate, order: .reverse)]
        )
        descriptor.fetchLimit = 20

        guard let records = try? context.fetch(descriptor), let latest = records.first else {
            return []
        }

        return records.filter { abs($0.fetchDate.timeIntervalSince(latest.fetchDate)) < 1 }
    }

    static func linkUnlinkedRecords(
        serviceName: String,
        to subscription: Subscription,
        in context: ModelContext
    ) {
        let descriptor = FetchDescriptor<PriceRecord>(
            predicate: #Predicate { $0.serviceName == serviceName && $0.subscription == nil },
            sortBy: [SortDescriptor(\.fetchDate, order: .reverse)]
        )
        guard let records = try? context.fetch(descriptor) else { return }
        for record in records {
            record.subscription = subscription
        }
    }
}
