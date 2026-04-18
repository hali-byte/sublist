import SwiftUI
import SwiftData

struct SubscriptionDetailView: View {
    @Bindable var subscription: Subscription
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subscription.nextRenewalDate) private var allSubscriptions: [Subscription]

    @AppStorage(AppConstants.currencyKey) private var currency: String = "USD"
    @AppStorage(AppConstants.countryCodeKey) private var countryCode: String = ""
    @State private var isDeleted = false
    @State private var showEmojiPicker = false
    @State private var isRefreshingPrices = false
    @State private var refreshCompleted = false
    @State private var refreshFailed = false
    @State private var refreshedPlans: [SubscriptionPlan]? = nil

    private var storedRecords: [PriceRecord] {
        PriceRecordService.latestRecords(
            for: subscription.name,
            countryCode: countryCode.isEmpty ? "US" : countryCode,
            in: modelContext
        )
    }

    private var hasProvider: Bool {
        ProviderRegistry.provider(for: subscription.name) != nil
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Button {
                        showEmojiPicker = true
                    } label: {
                        VStack(spacing: 5) {
                            SubscriptionIconView(name: subscription.name, emoji: subscription.emoji, size: 48)
                                .frame(width: 64, height: 64)
                            Text("Change icon")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    Text(subscription.name.isEmpty ? "Name" : subscription.name)
                        .font(.title2.bold())
                        .foregroundStyle(subscription.name.isEmpty ? .secondary : .primary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section("Details") {
                TextField("Name", text: $subscription.name)
                Picker("Category", selection: $subscription.category) {
                    ForEach(Category.allCases, id: \.self) { cat in
                        Text(cat.localizedName).tag(cat)
                    }
                }
            }

            Section("Billing") {
                TextField("Amount", value: $subscription.amount, format: .currency(code: currency))
                    .keyboardType(.decimalPad)
                Picker("Billing Cycle", selection: $subscription.billingCycle) {
                    ForEach(BillingCycle.allCases, id: \.self) { cycle in
                        Text(cycle.localizedName).tag(cycle)
                    }
                }
                DatePicker("Next Renewal", selection: $subscription.nextRenewalDate, displayedComponents: .date)
            }

            if hasProvider {
                planTiersSection
            }

            Section {
                Button("Mark as Renewed") {
                    markAsRenewed()
                }
            } footer: {
                Text("Advances the renewal date by one billing cycle.")
            }

            Section {
                Button("Delete Subscription", role: .destructive) {
                    isDeleted = true
                    NotificationManager.shared.cancel(for: subscription)
                    modelContext.delete(subscription)
                    dismiss()
                }
            }
        }
        .navigationTitle(subscription.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView(selectedEmoji: $subscription.emoji)
        }
        .onDisappear {
            if !isDeleted {
                NotificationManager.shared.scheduleAll(for: allSubscriptions)
            }
        }
    }

    @ViewBuilder
    private var planTiersSection: some View {
        Section {
            if isRefreshingPrices {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Refreshing prices\u{2026}")
                        .foregroundStyle(.secondary)
                }
            } else if let plans = refreshedPlans, !plans.isEmpty {
                ForEach(Array(plans.enumerated()), id: \.offset) { _, plan in
                    tierRow(
                        name: plan.name,
                        price: NSDecimalNumber(decimal: plan.price).doubleValue,
                        currency: plan.currency,
                        billingPeriod: plan.billingPeriod
                    )
                }
            } else if !storedRecords.isEmpty {
                ForEach(Array(storedRecords.enumerated()), id: \.offset) { _, record in
                    tierRow(
                        name: record.planName,
                        price: record.price,
                        currency: record.currency,
                        billingPeriod: record.billingPeriod
                    )
                }
            } else {
                Text("No pricing data yet. Tap refresh to fetch current prices.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if isRefreshingPrices {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Refreshing prices\u{2026}")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if refreshCompleted {
                Label("Prices updated", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            } else if refreshFailed {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Could not refresh prices", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await refreshPrices() }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.footnote.weight(.medium))
                    }
                }
            } else {
                Button {
                    Task { await refreshPrices() }
                } label: {
                    Label("Refresh Prices", systemImage: "arrow.clockwise")
                }
            }
        } header: {
            Text("Available Plans")
        } footer: {
            if let savings = bestSavings {
                Text("You could save \(savings.amount.formatted(.currency(code: currency)))/\(savings.period) by switching to \(savings.planName).")
            }
        }
    }

    @ViewBuilder
    private func tierRow(name: String, price: Double, currency: String, billingPeriod: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .fontWeight(.medium)
                let period = billingPeriod.lowercased().hasPrefix("year") ? "year" : "month"
                Text("\(price.formatted(.currency(code: currency))) / \(period)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isCurrentTier(price: price, period: billingPeriod) {
                Text("Current")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(.accent)
                    .clipShape(Capsule())
            }
        }
    }

    private func isCurrentTier(price: Double, period: String) -> Bool {
        let isMatchingPeriod = (period.lowercased().hasPrefix("year") && subscription.billingCycle == .yearly) ||
            (period.lowercased().hasPrefix("month") && subscription.billingCycle == .monthly)
        return isMatchingPeriod && abs(price - subscription.amount) < 0.01
    }

    private var bestSavings: (planName: String, amount: Double, period: String)? {
        struct Tier { let name: String; let price: Double; let billingPeriod: String }

        let tiers: [Tier]
        if let plans = refreshedPlans {
            tiers = plans.map { Tier(name: $0.name, price: NSDecimalNumber(decimal: $0.price).doubleValue, billingPeriod: $0.billingPeriod) }
        } else if !storedRecords.isEmpty {
            tiers = storedRecords.map { Tier(name: $0.planName, price: $0.price, billingPeriod: $0.billingPeriod) }
        } else {
            return nil
        }

        let period = subscription.billingCycle == .yearly ? "year" : "month"
        let matching = tiers.filter {
            $0.billingPeriod.lowercased().hasPrefix(period.prefix(1).lowercased())
        }

        guard let cheapest = matching.min(by: { $0.price < $1.price }),
              cheapest.price < subscription.amount - 0.01 else {
            return nil
        }

        return (planName: cheapest.name, amount: subscription.amount - cheapest.price, period: period)
    }

    private func refreshPrices() async {
        guard let provider = ProviderRegistry.provider(for: subscription.name) else { return }
        isRefreshingPrices = true
        refreshCompleted = false
        refreshFailed = false

        let code = countryCode.isEmpty ? "US" : countryCode
        do {
            let plans = try await PricingService.shared.fetchPlans(for: code, using: provider)
            isRefreshingPrices = false
            if !plans.isEmpty {
                PriceRecordService.store(
                    plans: plans,
                    serviceName: subscription.name,
                    countryCode: code,
                    subscription: subscription,
                    in: modelContext
                )
                refreshedPlans = plans
                refreshCompleted = true
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                refreshCompleted = false
            } else {
                refreshFailed = true
            }
        } catch {
            isRefreshingPrices = false
            refreshFailed = true
        }
    }

    private func markAsRenewed() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        subscription.markAsRenewed()
        NotificationManager.shared.schedule(for: subscription)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        updateWidgetSnapshot(from: allSubscriptions, currency: currency)
    }
}

#Preview {
    NavigationStack {
        SubscriptionDetailPreviewHelper()
    }
    .modelContainer(for: [Subscription.self, PriceRecord.self], inMemory: true)
}

private struct SubscriptionDetailPreviewHelper: View {
    @Query private var subscriptions: [Subscription]
    @Environment(\.modelContext) private var context

    var body: some View {
        if let sub = subscriptions.first {
            SubscriptionDetailView(subscription: sub)
        } else {
            ProgressView()
                .task {
                    context.insert(Subscription(
                        name: "Spotify",
                        amount: 9.99,
                        billingCycle: .monthly,
                        nextRenewalDate: Calendar.current.date(byAdding: .day, value: 14, to: .now)!,
                        category: .music,
                        emoji: "🎵"
                    ))
                }
        }
    }
}
