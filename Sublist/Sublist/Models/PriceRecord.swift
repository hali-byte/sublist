import Foundation
import SwiftData

@Model
class PriceRecord {
    var id: UUID = UUID()
    var serviceName: String
    var planName: String
    var price: Double
    var currency: String
    var billingPeriod: String
    var countryCode: String
    var fetchDate: Date
    var subscription: Subscription?

    init(
        serviceName: String,
        planName: String,
        price: Double,
        currency: String,
        billingPeriod: String,
        countryCode: String,
        fetchDate: Date = .now,
        subscription: Subscription? = nil
    ) {
        self.serviceName = serviceName
        self.planName = planName
        self.price = price
        self.currency = currency
        self.billingPeriod = billingPeriod
        self.countryCode = countryCode
        self.fetchDate = fetchDate
        self.subscription = subscription
    }
}
