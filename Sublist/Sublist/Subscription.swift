import Foundation
import SwiftData

@Model
class Subscription {
    var id: UUID = UUID()
    var name: String
    var amount: Double
    var billingCycle: BillingCycle
    var nextRenewalDate: Date
    var category: Category
    var emoji: String

    var monthlyCost: Double {
        billingCycle == .yearly ? amount / 12.0 : amount
    }

    var daysUntilRenewal: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: nextRenewalDate)
        ).day ?? 0
    }

    init(
        name: String,
        amount: Double,
        billingCycle: BillingCycle,
        nextRenewalDate: Date,
        category: Category,
        emoji: String
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.billingCycle = billingCycle
        self.nextRenewalDate = nextRenewalDate
        self.category = category
        self.emoji = emoji
    }
}

enum BillingCycle: String, Codable, CaseIterable {
    case monthly = "Monthly"
    case yearly  = "Yearly"
}

enum Category: String, Codable, CaseIterable {
    case entertainment = "Entertainment"
    case music         = "Music"
    case gaming        = "Gaming"
    case productivity  = "Productivity"
    case software      = "Software"
    case news          = "News & Reading"
    case fitness       = "Fitness"
    case health        = "Health & Wellness"
    case education     = "Education"
    case finance       = "Finance"
    case cloud         = "Cloud Storage"
    case security      = "Security & VPN"
    case other         = "Other"
}
