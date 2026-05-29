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
    /// When set and in the future, this subscription is on a free trial that
    /// converts to a paid charge of `amount` on this date. nil = not a trial.
    var trialEndDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \PriceRecord.subscription)
    var priceRecords: [PriceRecord] = []

    var monthlyCost: Double {
        billingCycle == .yearly ? amount / 12.0 : amount
    }

    /// True while the trial is still active (end date in the future).
    var isTrial: Bool {
        guard let trialEndDate else { return false }
        return trialEndDate > .now
    }

    var daysUntilTrialEnd: Int? {
        guard let trialEndDate else { return nil }
        return Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: trialEndDate)
        ).day
    }

    var daysUntilRenewal: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: nextRenewalDate)
        ).day ?? 0
    }

    func markAsRenewed() {
        let component: Calendar.Component = billingCycle == .monthly ? .month : .year
        if let newDate = Calendar.current.date(byAdding: component, value: 1, to: nextRenewalDate) {
            nextRenewalDate = newDate
        }
    }

    init(
        name: String,
        amount: Double,
        billingCycle: BillingCycle,
        nextRenewalDate: Date,
        category: Category,
        emoji: String,
        trialEndDate: Date? = nil
    ) {
        self.name = name
        self.amount = amount
        self.billingCycle = billingCycle
        self.nextRenewalDate = nextRenewalDate
        self.category = category
        self.emoji = emoji
        self.trialEndDate = trialEndDate
    }
}

enum BillingCycle: String, Codable, CaseIterable {
    case monthly = "Monthly"
    case yearly = "Yearly"

    var localizedName: String {
        switch self {
        case .monthly: String(localized: "Monthly", comment: "Monthly billing cycle")
        case .yearly: String(localized: "Yearly", comment: "Yearly billing cycle")
        }
    }
}

enum Category: String, Codable, CaseIterable {
    case entertainment = "Entertainment"
    case music = "Music"
    case gaming = "Gaming"
    case productivity = "Productivity"
    case software = "Software"
    case news = "News & Reading"
    case fitness = "Fitness"
    case health = "Health & Wellness"
    case education = "Education"
    case finance = "Finance"
    case cloud = "Cloud Storage"
    case security = "Security & VPN"
    case other = "Other"

    var localizedName: String {
        switch self {
        case .entertainment: String(localized: "Entertainment", comment: "Subscription category")
        case .music: String(localized: "Music", comment: "Subscription category")
        case .gaming: String(localized: "Gaming", comment: "Subscription category")
        case .productivity: String(localized: "Productivity", comment: "Subscription category")
        case .software: String(localized: "Software", comment: "Subscription category")
        case .news: String(localized: "News & Reading", comment: "Subscription category")
        case .fitness: String(localized: "Fitness", comment: "Subscription category")
        case .health: String(localized: "Health & Wellness", comment: "Subscription category")
        case .education: String(localized: "Education", comment: "Subscription category")
        case .finance: String(localized: "Finance", comment: "Subscription category")
        case .cloud: String(localized: "Cloud Storage", comment: "Subscription category")
        case .security: String(localized: "Security & VPN", comment: "Subscription category")
        case .other: String(localized: "Other", comment: "Subscription category")
        }
    }
}
