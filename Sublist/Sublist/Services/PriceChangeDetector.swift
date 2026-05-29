import Foundation
import SwiftData

enum PriceChangeType {
    case increased(old: Double, new: Double)
    case decreased(old: Double, new: Double)
    case cheaperPlanAvailable(planName: String, price: Double)
}

@MainActor
enum PriceChangeDetector {
    static func detectChanges(
        for subscription: Subscription,
        latestPlans: [SubscriptionPlan],
        in context: ModelContext
    ) -> PriceChangeType? {
        let period = subscription.billingCycle == .yearly ? "year" : "month"
        let matchingPlans = latestPlans.filter {
            $0.billingPeriod.lowercased().hasPrefix(period.prefix(1).lowercased())
        }

        let currentAmount = subscription.amount
        let tolerance = priceTolerance()
        if let closest = matchingPlans.min(by: {
            abs(NSDecimalNumber(decimal: $0.price).doubleValue - currentAmount) <
            abs(NSDecimalNumber(decimal: $1.price).doubleValue - currentAmount)
        }) {
            let newPrice = NSDecimalNumber(decimal: closest.price).doubleValue
            if newPrice > currentAmount + tolerance {
                return .increased(old: currentAmount, new: newPrice)
            } else if newPrice < currentAmount - tolerance {
                return .decreased(old: currentAmount, new: newPrice)
            }
        }

        if let cheapest = matchingPlans.min(by: {
            NSDecimalNumber(decimal: $0.price).doubleValue < NSDecimalNumber(decimal: $1.price).doubleValue
        }) {
            let cheapestPrice = NSDecimalNumber(decimal: cheapest.price).doubleValue
            if cheapestPrice < currentAmount - tolerance {
                return .cheaperPlanAvailable(planName: cheapest.name, price: cheapestPrice)
            }
        }

        return nil
    }

    static func detectFromRecords(
        for subscription: Subscription,
        in context: ModelContext
    ) -> PriceChangeType? {
        let name = subscription.name
        let period = subscription.billingCycle == .yearly ? "year" : "month"
        let currentAmount = subscription.amount

        var descriptor = FetchDescriptor<PriceRecord>(
            predicate: #Predicate { $0.serviceName == name },
            sortBy: [SortDescriptor(\.fetchDate, order: .reverse)]
        )
        descriptor.fetchLimit = 20

        guard let records = try? context.fetch(descriptor),
              let latestDate = records.first?.fetchDate else {
            return nil
        }

        let latestBatch = records.filter { abs($0.fetchDate.timeIntervalSince(latestDate)) < 1 }
        let matching = latestBatch.filter { $0.billingPeriod.lowercased().hasPrefix(period.prefix(1).lowercased()) }

        let tolerance = priceTolerance()
        if let closest = matching.min(by: {
            abs($0.price - currentAmount) < abs($1.price - currentAmount)
        }) {
            if closest.price > currentAmount + tolerance {
                return .increased(old: currentAmount, new: closest.price)
            } else if closest.price < currentAmount - tolerance {
                return .decreased(old: currentAmount, new: closest.price)
            }
        }

        if let cheapest = matching.min(by: { $0.price < $1.price }) {
            if cheapest.price < currentAmount - tolerance {
                return .cheaperPlanAvailable(planName: cheapest.planName, price: cheapest.price)
            }
        }

        return nil
    }

    /// Smallest price delta treated as a real change, based on the user's
    /// selected currency (e.g. ~0.005 for USD, 0.5 for JPY/KRW).
    private static func priceTolerance() -> Double {
        let currency = UserDefaults.standard.string(forKey: AppConstants.currencyKey) ?? "USD"
        return CurrencyFormatting.priceTolerance(for: currency)
    }
}
