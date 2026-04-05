import Foundation

struct SubscriptionPlan: Identifiable {
    let id = UUID()
    let name: String          // e.g. "Individual", "Duo", "Family"
    let price: Decimal
    let currency: String      // ISO 4217, e.g. "EUR"
    let billingPeriod: String // "month" or "year"
}
