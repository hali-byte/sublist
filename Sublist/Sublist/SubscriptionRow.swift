import SwiftUI

struct SubscriptionRow: View {
    let subscription: Subscription
    @AppStorage(AppConstants.currencyKey) private var currency: String = "USD"

    private var renewalLabel: String {
        switch subscription.daysUntilRenewal {
        case ..<0: return "Overdue"
        case 0:    return "Today"
        case 1:    return "Tomorrow"
        default:   return "In \(subscription.daysUntilRenewal)d"
        }
    }

    private var renewalColor: Color {
        switch subscription.daysUntilRenewal {
        case ..<2:  return .red
        case 2...7: return .orange
        default:    return .secondary
        }
    }

    var body: some View {
        HStack {
            SubscriptionIconView(name: subscription.name, emoji: subscription.emoji, size: 26)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name)
                    .font(.headline)
                Text(subscription.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 12)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(subscription.amount, format: .currency(code: currency))
                    .font(.headline.monospacedDigit())
                Text(renewalLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(renewalColor)
            }
        }
        .padding(.vertical, 4)
    }
}
