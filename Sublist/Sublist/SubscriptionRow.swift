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
            SubscriptionIconView(name: subscription.name, emoji: subscription.emoji, size: 28)
                .frame(width: 44, height: 44)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name)
                    .font(.headline)
                Text(subscription.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(subscription.amount, format: .currency(code: currency))
                    .font(.headline)
                Text(renewalLabel)
                    .font(.caption)
                    .foregroundStyle(renewalColor)
            }
        }
        .padding(.vertical, 4)
    }
}
