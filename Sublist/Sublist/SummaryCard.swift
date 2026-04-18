import SwiftUI

struct SummaryCard: View {
    let subscriptions: [Subscription]
    let currency: String
    let onBreakdownTap: () -> Void
    let onCalendarTap: () -> Void

    private var monthlyTotal: Double {
        subscriptions.reduce(0) { $0 + $1.monthlyCost }
    }

    private var topCategory: (name: String, amount: Double)? {
        let grouped = Dictionary(grouping: subscriptions, by: \.category)
        guard let top = grouped.max(by: {
            $0.value.reduce(0) { $0 + $1.monthlyCost } < $1.value.reduce(0) { $0 + $1.monthlyCost }
        }) else { return nil }
        let amount = top.value.reduce(0) { $0 + $1.monthlyCost }
        return (name: top.key.localizedName, amount: amount)
    }

    private var renewalsThisMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.startOfDay(for: now))!
        return subscriptions.filter { $0.nextRenewalDate <= endOfMonth && $0.nextRenewalDate >= now }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

                if let top = topCategory {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(categoryColor(for: top.name))
                            .frame(width: 6, height: 6)
                        Text("Top: \(top.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("(\(top.amount.formatted(.currency(code: currency)))/mo)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            Button(action: onBreakdownTap) {
                HStack {
                    Label("Category Breakdown", systemImage: "chart.pie")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)

            Divider().padding(.horizontal, 16)

            Button(action: onCalendarTap) {
                HStack {
                    Label {
                        HStack(spacing: 6) {
                            Text("Renewal Calendar")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            if renewalsThisMonth > 0 {
                                Text("\(renewalsThisMonth)")
                                    .font(.caption2.weight(.bold).monospacedDigit())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    private func categoryColor(for name: String) -> Color {
        Category.allCases.first { $0.localizedName == name }?.chartColor ?? .secondary
    }
}

#Preview {
    let subs = [
        Subscription(name: "Spotify",  amount: 9.99,  billingCycle: .monthly, nextRenewalDate: .now, category: .music,         emoji: "🎵"),
        Subscription(name: "Netflix",  amount: 15.99, billingCycle: .monthly, nextRenewalDate: .now, category: .entertainment,  emoji: "🎬"),
        Subscription(name: "iCloud+",  amount: 35.99, billingCycle: .yearly,  nextRenewalDate: .now, category: .cloud,          emoji: "☁️"),
    ]
    SummaryCard(subscriptions: subs, currency: "USD", onBreakdownTap: {}, onCalendarTap: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
