import SwiftUI

struct SummaryCard: View {
    let subscriptions: [Subscription]
    let currency: String
    let onBreakdownTap: () -> Void

    private var monthlyTotal: Double {
        subscriptions.reduce(0) { $0 + $1.monthlyCost }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly spend")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(monthlyTotal, format: .currency(code: currency))
                        .font(.largeTitle.bold().monospacedDigit())
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: monthlyTotal)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Per year")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(monthlyTotal * 12, format: .currency(code: currency))
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: monthlyTotal)
                }
                .padding(.top, 2)
            }

            Divider()

            Button(action: onBreakdownTap) {
                HStack {
                    Text("Category Breakdown")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

#Preview {
    let subs = [
        Subscription(name: "Spotify",  amount: 9.99,  billingCycle: .monthly, nextRenewalDate: .now, category: .music,         emoji: "🎵"),
        Subscription(name: "Netflix",  amount: 15.99, billingCycle: .monthly, nextRenewalDate: .now, category: .entertainment,  emoji: "🎬"),
        Subscription(name: "iCloud+",  amount: 35.99, billingCycle: .yearly,  nextRenewalDate: .now, category: .cloud,          emoji: "☁️"),
    ]
    SummaryCard(subscriptions: subs, currency: "USD", onBreakdownTap: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
