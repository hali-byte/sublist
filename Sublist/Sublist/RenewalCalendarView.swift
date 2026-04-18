import SwiftUI
import SwiftData

struct RenewalCalendarView: View {
    let subscriptions: [Subscription]
    @AppStorage(AppConstants.currencyKey) private var currency: String = "USD"
    @State private var selectedDate: Date? = nil
    @State private var displayedMonth = Date()

    private var calendar: Calendar { Calendar.current }

    private var renewalsByDay: [DateComponents: [Subscription]] {
        Dictionary(grouping: subscriptions) { sub in
            calendar.dateComponents([.year, .month, .day], from: sub.nextRenewalDate)
        }
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        return range.compactMap { day in
            calendar.date(from: DateComponents(year: components.year, month: components.month, day: day))
        }
    }

    private var firstWeekdayOffset: Int {
        guard let firstDay = daysInMonth.first else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDay)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var monthlyRenewalCost: Double {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        return subscriptions
            .filter { calendar.dateComponents([.year, .month], from: $0.nextRenewalDate) == components }
            .reduce(0) { $0 + $1.amount }
    }

    private var subscriptionsForSelectedDate: [Subscription] {
        guard let date = selectedDate else { return [] }
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return renewalsByDay[comps] ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                calendarCard
                if !subscriptionsForSelectedDate.isEmpty {
                    selectedDateCard
                }
                monthSummaryCard
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .navigationTitle("Renewal Calendar")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Calendar card

    private var calendarCard: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                        selectedDate = nil
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }

                Spacer()
                Text(monthTitle)
                    .font(.headline)
                    .contentTransition(.numericText())
                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                        selectedDate = nil
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 4)

            weekdayHeaders
            calendarGrid
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var reorderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    private var weekdayHeaders: some View {
        LazyVGrid(columns: gridColumns, spacing: 0) {
            ForEach(reorderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .frame(height: 20)
            }
        }
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 6) {
            ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                Color.clear.frame(height: 40)
            }
            ForEach(daysInMonth, id: \.self) { date in
                dayCell(date)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let renewals = renewalsByDay[comps] ?? []
        let isToday = calendar.isDateInToday(date)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if isSelected {
                    selectedDate = nil
                } else {
                    selectedDate = date
                }
            }
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.callout.monospacedDigit())
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(foregroundForDay(isToday: isToday, isSelected: isSelected, hasRenewals: !renewals.isEmpty))
                    .frame(width: 32, height: 32)
                    .background {
                        if isSelected {
                            Circle().fill(Color.accentColor)
                        } else if isToday {
                            Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                        }
                    }

                HStack(spacing: 2) {
                    ForEach(renewals.prefix(3)) { sub in
                        Circle()
                            .fill(sub.category.chartColor)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .buttonStyle(.plain)
        .frame(height: 40)
    }

    private func foregroundForDay(isToday: Bool, isSelected: Bool, hasRenewals: Bool) -> Color {
        if isSelected { return .white }
        if hasRenewals { return .primary }
        return .secondary
    }

    // MARK: - Selected date detail

    private var selectedDateCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let date = selectedDate {
                Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                ForEach(Array(subscriptionsForSelectedDate.enumerated()), id: \.element.id) { index, sub in
                    VStack(spacing: 0) {
                        if index > 0 {
                            Divider().padding(.leading, 46)
                        }
                        HStack(spacing: 12) {
                            SubscriptionIconView(name: sub.name, emoji: sub.emoji, size: 22)
                                .frame(width: 30, height: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.name)
                                    .font(.subheadline.weight(.medium))
                                Text(sub.billingCycle.localizedName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(sub.amount, format: .currency(code: currency))
                                .font(.subheadline.weight(.medium).monospacedDigit())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Month summary

    private var monthSummaryCard: some View {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        let monthSubs = subscriptions.filter {
            calendar.dateComponents([.year, .month], from: $0.nextRenewalDate) == components
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text("This month")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(monthSubs.count)")
                        .font(.title2.bold().monospacedDigit())
                    Text("Renewals")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(monthlyRenewalCost, format: .currency(code: currency))
                        .font(.title2.bold().monospacedDigit())
                    Text("Total cost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let next = monthSubs.sorted(by: { $0.nextRenewalDate < $1.nextRenewalDate }).first(where: { $0.nextRenewalDate >= Date() }) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(next.nextRenewalDate.formatted(.dateTime.day().month(.abbreviated)))
                            .font(.title2.bold().monospacedDigit())
                        Text("Next up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    let subs = [
        Subscription(name: "Spotify", amount: 9.99, billingCycle: .monthly,
                     nextRenewalDate: Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
                     category: .music, emoji: "🎵"),
        Subscription(name: "Netflix", amount: 15.99, billingCycle: .monthly,
                     nextRenewalDate: Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
                     category: .entertainment, emoji: "🎬"),
        Subscription(name: "iCloud+", amount: 2.99, billingCycle: .monthly,
                     nextRenewalDate: Calendar.current.date(byAdding: .day, value: 12, to: .now)!,
                     category: .cloud, emoji: "☁️"),
        Subscription(name: "ChatGPT Plus", amount: 20.00, billingCycle: .monthly,
                     nextRenewalDate: Calendar.current.date(byAdding: .day, value: 20, to: .now)!,
                     category: .productivity, emoji: "🤖"),
    ]
    NavigationStack {
        RenewalCalendarView(subscriptions: subs)
    }
}
