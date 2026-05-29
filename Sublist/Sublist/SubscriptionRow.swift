import SwiftUI
import SwiftData

struct SubscriptionRow: View {
    let subscription: Subscription
    var isGrouped: Bool = false
    var priceChange: PriceChangeType? = nil
    @AppStorage(AppConstants.currencyKey) private var currency: String = "USD"

    private var renewalLabel: String {
        switch subscription.daysUntilRenewal {
        case ..<0: return String(localized: "Overdue",   comment: "Subscription is past its renewal date")
        case 0:    return String(localized: "Due today", comment: "Subscription renews today")
        case 1:    return String(localized: "Tomorrow",  comment: "Subscription renews tomorrow")
        default:   return String(localized: "In \(subscription.daysUntilRenewal) days", comment: "Days until subscription renews")
        }
    }

    private var renewalColor: Color {
        switch subscription.daysUntilRenewal {
        case ..<2:  return .red
        case 2...7: return .orange
        default:    return .secondary
        }
    }

    private var trialLabel: String {
        switch subscription.daysUntilTrialEnd ?? 0 {
        case ..<0: return String(localized: "Trial ended", comment: "Free trial has ended")
        case 0:    return String(localized: "Trial ends today", comment: "Free trial ends today")
        case 1:    return String(localized: "Trial ends tomorrow", comment: "Free trial ends tomorrow")
        default:   return String(localized: "Trial: \(subscription.daysUntilTrialEnd ?? 0)d left", comment: "Days left in free trial")
        }
    }

    var body: some View {
        if isGrouped {
            rowContent
        } else {
            rowContent
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }

    private var rowContent: some View {
        HStack(spacing: 14) {
            SubscriptionIconView(name: subscription.name, emoji: subscription.emoji, size: 22)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name)
                    .font(.headline)
                HStack(spacing: 5) {
                    Text(subscription.billingCycle.localizedName)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                        .fixedSize()
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(subscription.category.localizedName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(subscription.amount, format: .currency(code: currency))
                    .font(.subheadline.bold().monospacedDigit())
                if subscription.billingCycle == .yearly {
                    Text("≈ \(subscription.monthlyCost.formatted(.currency(code: currency)))/mo")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let change = priceChange {
                    priceChangeBadge(change)
                }
                if subscription.isTrial {
                    Text(trialLabel)
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                } else if subscription.daysUntilRenewal <= 0 {
                    Text(renewalLabel)
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Text(renewalLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(renewalColor)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let amount = subscription.amount.formatted(.currency(code: currency))
        var parts = [
            subscription.name,
            subscription.billingCycle.localizedName,
            subscription.category.localizedName,
            amount,
        ]
        if let change = priceChange {
            switch change {
            case .increased: parts.append(String(localized: "Price increased"))
            case .decreased: parts.append(String(localized: "Price decreased"))
            case .cheaperPlanAvailable: parts.append(String(localized: "Cheaper plan available"))
            }
        }
        parts.append(subscription.isTrial ? trialLabel : renewalLabel)
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private func priceChangeBadge(_ change: PriceChangeType) -> some View {
        switch change {
        case .increased:
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                Text("Price up")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.red)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red.opacity(0.1))
            .clipShape(Capsule())
        case .decreased:
            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                Text("Price down")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.green)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.green.opacity(0.1))
            .clipShape(Capsule())
        case .cheaperPlanAvailable:
            HStack(spacing: 2) {
                Image(systemName: "lightbulb.fill")
                Text("Cheaper plan")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}

#Preview {
    let subs = [
        Subscription(name: "Netflix",  amount: 15.99, billingCycle: .monthly,
                     nextRenewalDate: .now,
                     category: .entertainment, emoji: "🎬"),
        Subscription(name: "iCloud+",  amount: 35.99, billingCycle: .yearly,
                     nextRenewalDate: Calendar.current.date(byAdding: .day, value: 45, to: .now)!,
                     category: .cloud, emoji: "☁️"),
        Subscription(name: "Spotify",  amount: 9.99,  billingCycle: .monthly,
                     nextRenewalDate: Calendar.current.date(byAdding: .day, value: 4, to: .now)!,
                     category: .music, emoji: "🎵"),
    ]
    VStack(spacing: 10) {
        ForEach(Array(subs.enumerated()), id: \.offset) { index, sub in
            SubscriptionRow(subscription: sub, isGrouped: index == subs.count - 1)
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
