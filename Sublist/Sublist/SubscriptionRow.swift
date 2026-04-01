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
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.06), radius: 0, x: 0, y: 0)
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)

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
                    .font(.headline.monospacedDigit())
                Text(renewalLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(renewalColor)
            }
        }
        .padding(.vertical, 4)
    }
}
