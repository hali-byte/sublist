import Foundation

struct SubscriptionSnapshot: Codable {
    let name: String
    let emoji: String
    let amount: Double
    let billingCycle: String
    let nextRenewalDate: Date
    let currency: String
}
