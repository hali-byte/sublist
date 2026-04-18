import SwiftUI
import Charts
import SwiftData

// MARK: - Data model

struct CategorySpend: Identifiable {
    let category: Category
    let amount: Double
    let count: Int
    var id: String { category.rawValue }
}

// MARK: - Category colours (view-only concern)

extension Category {
    var chartColor: Color {
        switch self {
        case .entertainment: return Color(red: 0.58, green: 0.27, blue: 0.98)
        case .music:         return Color(red: 0.96, green: 0.28, blue: 0.46)
        case .gaming:        return Color(red: 0.35, green: 0.44, blue: 0.97)
        case .productivity:  return Color(red: 0.20, green: 0.60, blue: 0.98)
        case .software:      return Color(red: 0.12, green: 0.78, blue: 0.90)
        case .news:          return Color(red: 0.98, green: 0.58, blue: 0.15)
        case .fitness:       return Color(red: 0.24, green: 0.82, blue: 0.49)
        case .health:        return Color(red: 0.18, green: 0.78, blue: 0.72)
        case .education:     return Color(red: 0.98, green: 0.80, blue: 0.12)
        case .finance:       return Color(red: 0.18, green: 0.68, blue: 0.60)
        case .cloud:         return Color(red: 0.45, green: 0.72, blue: 0.98)
        case .security:      return Color(red: 0.97, green: 0.35, blue: 0.35)
        case .other:         return Color(red: 0.55, green: 0.55, blue: 0.60)
        }
    }
}

// MARK: - Main view

struct SpendingChartView: View {
    let subscriptions: [Subscription]
    @AppStorage(AppConstants.currencyKey) private var currency: String = "USD"
    @State private var selectedID: String? = nil

    private var spends: [CategorySpend] {
        Dictionary(grouping: subscriptions, by: \.category)
            .compactMap { cat, subs -> CategorySpend? in
                let total = subs.reduce(0) { $0 + $1.monthlyCost }
                return total > 0 ? CategorySpend(category: cat, amount: total, count: subs.count) : nil
            }
            .sorted { $0.amount > $1.amount }
    }

    private var total: Double { spends.reduce(0) { $0 + $1.amount } }

    private var selected: CategorySpend? {
        guard let id = selectedID else { return nil }
        return spends.first { $0.id == id }
    }

    private var insight: String? {
        guard let top = spends.first, total > 0 else { return nil }
        let pct = Int((top.amount / total) * 100)
        let categoryName = top.category.localizedName
        if pct >= 50 {
            return String(localized: "\(categoryName) accounts for \(pct)% of your spend.", comment: "Insight when one category dominates spending")
        }
        if spends.count == 1 {
            return String(localized: "All your subscriptions are in \(categoryName).", comment: "Insight when all subs are in one category")
        }
        let catCount = spends.count
        let subCount = subscriptions.count
        return String(localized: "\(catCount) categories across \(subCount) subscriptions.", comment: "Insight showing spread of subscriptions")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                donutCard
                if let text = insight {
                    insightBanner(text)
                }
                breakdownCard
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .navigationTitle("Breakdown")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Insight banner

    private func insightBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.subheadline)
                .foregroundStyle(.yellow)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Donut card

    private var donutCard: some View {
        ZStack {
            Chart(spends) { spend in
                SectorMark(
                    angle: .value("Amount", spend.amount),
                    innerRadius: .ratio(0.62),
                    angularInset: 2
                )
                .cornerRadius(5)
                .foregroundStyle(spend.category.chartColor)
                .opacity(selectedID == nil || selectedID == spend.id ? 1 : 0.2)
            }
            .frame(height: 260)
            .animation(.easeInOut(duration: 0.2), value: selectedID)

            centerLabel
            centerHoleTapTarget
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var centerHoleTapTarget: some View {
        Circle()
            .fill(Color.clear)
            .frame(width: 148, height: 148)
            .contentShape(Circle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) { selectedID = nil }
            }
    }

    private var centerLabel: some View {
        ZStack {
            if let s = selected {
                VStack(spacing: 3) {
                    Text(s.category.localizedName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 110)
                    Text(s.amount, format: .currency(code: currency))
                        .font(.title3.bold().monospacedDigit())
                    HStack(spacing: 4) {
                        Text((s.amount / total).formatted(.percent.precision(.fractionLength(0))))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text("\u{00B7}")
                            .foregroundStyle(.tertiary)
                        Text("^[\(s.count) sub](inflect: true)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity.combined(with: .offset(y: 4)))
            } else {
                VStack(spacing: 3) {
                    Text("per month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(total, format: .currency(code: currency))
                        .font(.title3.bold().monospacedDigit())
                    Text("\(spends.count) categories")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .offset(y: -4)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedID)
    }

    // MARK: - Breakdown card

    private var breakdownCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(spends.enumerated()), id: \.element.id) { index, spend in
                breakdownRow(spend: spend, rank: index + 1, isLast: index == spends.count - 1)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func breakdownRow(spend: CategorySpend, rank: Int, isLast: Bool) -> some View {
        let isSelected = selectedID == spend.id
        let pct = total > 0 ? spend.amount / total : 0

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedID = isSelected ? nil : spend.id
            }
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(spend.category.chartColor.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Circle()
                            .fill(spend.category.chartColor)
                            .frame(width: 10, height: 10)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(spend.category.localizedName)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Text("^[\(spend.count) subscription](inflect: true)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(spend.amount, format: .currency(code: currency))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.primary)
                        Text(pct.formatted(.percent.precision(.fractionLength(0))))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isSelected
                    ? spend.category.chartColor.opacity(0.08)
                    : Color.clear)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Color(.systemGray5)
                        spend.category.chartColor
                            .opacity(selectedID == nil || selectedID == spend.id ? 0.55 : 0.15)
                            .frame(width: geo.size.width * pct)
                            .animation(.easeInOut(duration: 0.3), value: selectedID)
                    }
                }
                .frame(height: 2)

                if !isLast {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let subs = [
        Subscription(name: "Spotify",     amount: 9.99,  billingCycle: .monthly, nextRenewalDate: .now, category: .music,        emoji: "🎵"),
        Subscription(name: "Netflix",     amount: 15.99, billingCycle: .monthly, nextRenewalDate: .now, category: .entertainment, emoji: "🎬"),
        Subscription(name: "iCloud+",     amount: 2.99,  billingCycle: .monthly, nextRenewalDate: .now, category: .cloud,         emoji: "☁️"),
        Subscription(name: "ChatGPT Plus",amount: 20.00, billingCycle: .monthly, nextRenewalDate: .now, category: .productivity,  emoji: "🤖"),
    ]
    NavigationStack {
        SpendingChartView(subscriptions: subs)
    }
}
